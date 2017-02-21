/*eslint-env node*/
/*eslint no-unused-vars: ["error", { "args": "none" }]*/

var common = require("./common");
var config = common.config();

var https = require("https");

var httpProxy = require("http-proxy");
var swiftReverseProxy = httpProxy.createProxyServer({ secure: false});

var pkgcloud = require("pkgcloud");
var express = require("express");
var busboy = require("connect-busboy");
var cors = require("cors");
var app = express();

var errorhandler = require("errorhandler");

var logger = require("express-logger");
var winston = require("winston");

var crypto = require("crypto");

app.use(logger({ path: config.app.logger_path }));
app.use(busboy({ immediate: false }));

app.use(function (req, res, next) {
  res.removeHeader("X-Powered-By");
  next();
});

app.get("/status", function(req, res, next) {
  res.send("Alive!");
});

app.get("/os/:container_name/:key(*)", function(req, res, next) {
  req.url = req.url.replace(config.proxy.source_prefix, config.proxy.target_prefix);
  winston.info("PROXING " + req.url + " to " + config.proxy.target + "/" + config.proxy.target_prefix);
  // swiftReverseProxy.web(req, res, { target: config.proxy.target });
  var client = pkgcloud.storage.createClient(config.swift);
  var aes = crypto.createDecipher('aes-256-cbc', config.aesSecret);
  client.download({ container: req.params.container_name, remote: req.params.key }).pipe(aes).pipe(res);
});

var validateSignature = function(req, res, next) {
  var expires = req.query.expires || req.params.expires;
  var signature = req.query.signature || req.params.signature;

  var data = req.method + "\n" + expires + "\n" + req.params.container_name + "/" + req.params.key;
  var newSignature = crypto.createHmac("sha256", config.signed_url_secret).update(data).digest("hex");
  var timeLeft = parseInt(expires) - (parseInt(new Date().getTime() / 1000));

  if (newSignature !== signature || timeLeft < 1) {
    return res.status(401).send("Invalid URL");
  } else {
    return next();
  }
};

var uploadFile = function(req, res, next) {
  // -------------------------------------------- OpenStack Swift write stream - begin
  var client = pkgcloud.storage.createClient(config.swift);
  var writeStream = client.upload({ container: req.params.container_name, remote: req.params.key });

  writeStream.on("success", function(file) {
    res.send("OK");
  });

  writeStream.on("error", function(err) {
    winston.error(err);
    res.send("Error");
  });
  // -------------------------------------------- OpenStack Swift write stream - end

  if (!req.busboy) {
    // eg. request is run like `curl -XPUT -T file_name URL`
    req.on("data", function(chunk) {
      writeStream.write(chunk);

    });
    req.on("end", function() {
      writeStream.end();
    });
  } else {
    // eg. request is run like `curl -XPUT -F "file=@file_name" URL`, which encodes it as `application/x-www-urlform-encoded`
    req.busboy.on("file", function(name, fileStrem, filename, encoding, mimetype) {
      // fileStrem.pipe(writeStream);
      console.log("\n\n\n ============== BUSBOY ================ \n\n\n")
      var aes = crypto.createCipher('aes-256-cbc', config.aesSecret);
      fileStrem.pipe(aes).pipe(writeStream);
    });
    req.pipe(req.busboy);
  }
};

app.options("/os/:container_name/:key(*)", cors());
app.put("/os/:container_name/:key(*)", [cors(), validateSignature], uploadFile);

app.options("/:signature/:expires/os/:container_name/:key(*)", cors());
app.put("/:signature/:expires/os/:container_name/:key(*)", [cors(), validateSignature], uploadFile);

// Add file transport layer for winston logs.
winston.add(winston.transports.File, { filename: "logs/winston-" + process.env.NODE_ENV + ".log" });

if (process.env.NODE_ENV === "development") {
  app.use(errorhandler({ dumpExceptions: true, showStack: true }));
}

var runner = (function(config, app) {
  if (process.env.NODE_ENV === "production") {
    return https.createServer(config.ssl, app);
  } else {
    return app;
  }
})(config, app);

runner.listen(config.app.port, function () {
  winston.info("[" + process.env.NODE_ENV + "] Swift Proxy started on port " + config.app.port + ".");
});
