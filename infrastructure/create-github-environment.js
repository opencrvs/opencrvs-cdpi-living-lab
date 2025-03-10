const sodium = require('libsodium-wrappers')
const { Octokit } = require('@octokit/core')
const { writeFileSync } = require('fs')

const config = {
  environment: 'production',
  repo: {
    REPOSITORY: 'opencrvs/opencrvs-cdpi-living-lab', // e.g. opencrvs/opencrvs-farajaland
    DOCKERHUB_ACCOUNT: 'opencrvs', // This may be a dockerhub organisation or the same as the username
    DOCKERHUB_REPO: 'ocrvs-cdpi-living-lab',
    DOCKER_USERNAME: process.env.DOCKER_USERNAME,
    DOCKER_TOKEN: process.env.DOCKER_TOKEN
  },
  ssh: {
    KNOWN_HOSTS: process.env.KNOWN_HOSTS,
    SSH_HOST: process.env.SSH_HOST, // IP address for the manager
    SSH_USER: process.env.SSH_USER,
    // SUDO_PASSWORD: process.env.SUDO_PASSWORD, // in case your user is not root
    SSH_KEY: process.env.SSH_KEY // id_rsa
  },
  infrastructure: {
    DISK_SPACE: '100GB',
    HOSTNAME: 'ip-10-20-0-86', // server machine hostname used when provisioning - TODO: Adapt to support 3 or 5 replicas
    DOMAIN: 'opencrvs.labs.cdpi.dev', // web hostname applied after all public subdomains in Traefik,
    REPLICAS: '1' // TODO: Adapt to support 3 or 5 replicas
  },
  services: {
    SENTRY_DSN: process.env.SENTRY_DSN || '',
    ELASTALERT_SLACK_WEBHOOK: process.env.ELASTALERT_SLACK_WEBHOOK || '',
    INFOBIP_API_KEY: process.env.INFOBIP_API_KEY || '',
    INFOBIP_GATEWAY_ENDPOINT: process.env.INFOBIP_GATEWAY_ENDPOINT || '',
    INFOBIP_SENDER_ID: process.env.INFOBIP_SENDER_ID || '' // the name of the SMS sender e.g. OpenCRVS
  },
  seeding: {
    ACTIVATE_USERS: 'true',
    AUTH_HOST: 'https://auth.opencrvs.labs.cdpi.dev',
    COUNTRY_CONFIG_HOST: 'https://countryconfig.opencrvs.labs.cdpi.dev',
    GATEWAY_HOST: 'https://gateway.opencrvs.labs.cdpi.dev'
  },
  smtp: {
    SMTP_HOST: process.env.SMTP_HOST || '',
    SMTP_USERNAME: process.env.SMTP_USERNAME || '',
    SMTP_PASSWORD: process.env.SMTP_PASSWORD || '',
    EMAIL_API_KEY: process.env.EMAIL_API_KEY || '',
    SMTP_PORT: '',
    ALERT_EMAIL: ''
  },
  vpn: {
    // openconnect details for optional VPN
    VPN_PROTOCOL: '', // e,g, fortinet, wireguard etc
    VPN_HOST: process.env.VPN_HOST || '',
    VPN_PORT: process.env.VPN_PORT || '',
    VPN_USER: process.env.VPN_USER || '',
    VPN_PWD: process.env.VPN_PWD || '',
    VPN_SERVERCERT: process.env.VPN_SERVERCERT || ''
  },
  whitelist: {
    CONTENT_SECURITY_POLICY_WILDCARD: '*.opencrvs.labs.cdpi.dev', // e.g. *.<your-domain>
    CLIENT_APP_URL: 'https://register.opencrvs.labs.cdpi.dev',
    LOGIN_URL: 'https://login.opencrvs.labs.cdpi.dev'
  },
  backup: {
    BACKUP_HOST: process.env.BACKUP_HOST || '',
    BACKUP_DIRECTORY: '',
    qa: {
      RESTORE_DIRECTORY: '' // If making use of script to restore a production backup on QA for regular monitoring
    }
  }
}

const octokit = new Octokit({
  auth: process.env.GITHUB_TOKEN
})

async function fetchRepositoryId() {
  const response = await octokit.request(`GET /repos/${config.repo.REPOSITORY}`)
  return response.data.id.toString()
}

async function createVariable(repositoryId, environment, name, value) {
  await octokit.request(
    `POST /repositories/${repositoryId}/environments/${config.environment}/variables`,
    {
      repository_id: repositoryId,
      environment_name: environment,
      name: name,
      value: value,
      headers: {
        'X-GitHub-Api-Version': '2022-11-28'
      }
    }
  )
}

async function createSecret(
  repositoryId,
  environment,
  key,
  keyId,
  name,
  secret
) {
  //Check if libsodium is ready and then proceed.
  await sodium.ready

  // Convert Secret & Base64 key to Uint8Array.
  let binkey = sodium.from_base64(key, sodium.base64_variants.ORIGINAL)
  let binsec = sodium.from_string(secret)

  //Encrypt the secret using LibSodium
  let encBytes = sodium.crypto_box_seal(binsec, binkey)

  // Convert encrypted Uint8Array to Base64
  const encryptedValue = sodium.to_base64(
    encBytes,
    sodium.base64_variants.ORIGINAL
  )

  await octokit.request(
    `PUT /repositories/${repositoryId}/environments/${environment}/secrets/${name}`,
    {
      repository_id: repositoryId,
      environment_name: environment,
      secret_name: name,
      encrypted_value: encryptedValue,
      key_id: keyId,
      headers: {
        'X-GitHub-Api-Version': '2022-11-28'
      }
    }
  )
}

async function getPublicKey(repositoryId, environment) {
  await octokit.request(
    `PUT /repositories/${repositoryId}/environments/${environment}`,
    {
      headers: {
        'X-GitHub-Api-Version': '2022-11-28'
      }
    }
  )

  const res = await octokit.request(
    `GET /repositories/${repositoryId}/environments/${environment}/secrets/public-key`,
    {
      headers: {
        'X-GitHub-Api-Version': '2022-11-28'
      }
    }
  )

  return res.data
}

function generateLongPassword() {
  const chars =
    '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-_'
  let result = ''
  for (var i = 16; i > 0; --i)
    result += chars[Math.floor(Math.random() * chars.length)]
  return result
}

async function main() {
  const repositoryId = await fetchRepositoryId()
  const { key, key_id } = await getPublicKey(repositoryId, config.environment)
  let backupSecrets = {}
  let backupVariables = {}
  let vpnSecrets = {}

  if (process.argv.includes('--configure-backup')) {
    backupSecrets = {
      BACKUP_HOST: config.backup.BACKUP_HOST
    }
    backupVariables = {
      BACKUP_DIRECTORY: config.backup.BACKUP_DIRECTORY,
      RESTORE_DIRECTORY: config.backup.qa.RESTORE_DIRECTORY
    }
  }

  if (process.argv.includes('--configure-vpn')) {
    vpnSecrets = {
      ...config.vpn
    }
  }

  const SECRETS = {
    ELASTICSEARCH_SUPERUSER_PASSWORD: generateLongPassword(),
    ENCRYPTION_KEY: generateLongPassword(),
    KIBANA_USERNAME: 'opencrvs-admin',
    KIBANA_PASSWORD: generateLongPassword(),
    MINIO_ROOT_PASSWORD: generateLongPassword(),
    MINIO_ROOT_USER: generateLongPassword(),
    MONGODB_ADMIN_PASSWORD: generateLongPassword(),
    MONGODB_ADMIN_USER: generateLongPassword(),
    SUPER_USER_PASSWORD: generateLongPassword(),
    DOCKERHUB_ACCOUNT: config.repo.DOCKERHUB_ACCOUNT,
    DOCKERHUB_REPO: config.repo.DOCKERHUB_REPO,
    DOCKER_TOKEN: config.repo.DOCKER_TOKEN,
    ...config.ssh,
    ...config.smtp,
    ...config.services,
    ...backupSecrets,
    ...vpnSecrets
  }
  const VARIABLES = {
    ...config.infrastructure,
    ...config.seeding,
    ...config.whitelist,
    ...backupVariables
  }
  writeFileSync(
    './.secrets/' + config.environment + '.json',
    JSON.stringify([SECRETS, VARIABLES], null, 2)
  )
  if (process.argv.includes('--dry-run')) {
    console.log('Dry run. Not creating secrets or variables.')
    process.exit(0)
  } else {
    for (const [secretName, secretValue] of Object.entries(SECRETS)) {
      await createSecret(
        repositoryId,
        config.environment,
        key,
        key_id,
        secretName,
        secretValue
      )
    }

    for (const [variableName, variableValue] of Object.entries(VARIABLES)) {
      await createVariable(
        repositoryId,
        config.environment,
        variableName,
        variableValue
      )
    }
  }
}

main()
