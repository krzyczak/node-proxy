/*eslint-env node*/
var fs = require("fs");
var env = require("./env.json");

exports.config = function() {
  var node_env = process.env.NODE_ENV = (process.env.NODE_ENV || "development");

  require("dotenv").config();
  var settings = {
    swift: {
      provider: process.env.OS_PROVIDER,
      keystoneAuthVersion: process.env.OS_AUTH_VERSION,
      authUrl: process.env.OS_AUTH_URL,
      tenantId: process.env.OS_TENANT_ID,
      domainId: process.env.OS_DOMAIN_ID,
      username: process.env.OS_USERNAME,
      password: process.env.OS_PASSWORD,
      region: process.env.OS_REGION,
      strictSSL: false
    },
    proxy: {
      source_prefix: process.env.OS_PROXY_SOURCE_URL,
      target_prefix: process.env.OS_PROXY_TARGET_PREFIX,
      target: process.env.OS_PROXY_TARGET_URL
    },
    corsOptions: {
      origin: process.env.CORS_ALLOWED_ORIGIN,
      optionsSuccessStatus: 200
    },
    signed_url_secret: process.env.OS_TEMP_URL_SIGNATURE,
    ssl: {
      key: fs.readFileSync(process.env.SSL_KEY_FILE_PATH),
      cert: fs.readFileSync(process.env.SSL_CRT_FILE_PATH)
    }
  };

  return Object.assign(env[node_env], settings);
};

