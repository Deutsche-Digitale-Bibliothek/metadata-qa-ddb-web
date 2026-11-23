<?php

use Monolog\Logger;
use Monolog\Level;
use Monolog\Formatter\LineFormatter;
use Monolog\Handler\StreamHandler;
use Monolog\Handler\ErrorLogHandler;

class Configuration {
  private array $configuration;
  private string $logFile;
  private Level $logLevel;

  public static function fromIniFile(string $file) {

    // read INI file, remove sections and fields with empty string value
    $ini = @parse_ini_file($file, false, INI_SCANNER_TYPED);
    if (!$ini) {
      throw new Exception("failed to read config file!");
    }

    // merge in defaults
    return new Configuration($ini);
  }

  private function __construct(array $configuration) {
    $this->configuration = $this->injectEnvironmentalVariables($configuration);

    $this->logFile = $this->readValue('logFile', 'logs/metadata-qa-ddb.log');
    $this->logHandler = $this->readValue('logHandler', 'error_log');
    $this->logLevel = Logger::toMonologLevel($this->readValue('logLevel', 'WARNING'));
  }

   /**
   * Reads configuration file and override the keys with environmental variables
   * @return object|array
   */
  private function injectEnvironmentalVariables(array $configuration): array {
    $variables = ['INPUT_DIR', 'OUTPUT_DIR', 'MQAF_DB_HOST', 'MQAF_DB_PORT', 'MQAF_DB_DATABASE',
                  'MQAF_DB_USER', 'MQAF_DB_PASSWORD', 'MQAF_SOLR_HOST', 'MQAF_SOLR_PORT'];
    foreach ($variables as $key) {
      $value = $_ENV[$key] ?? getenv($key);
      if ($value !== false && $value !== '') {
        $configuration[$key] = $value;
      }
    }
    return $configuration;
  }

  private function readValue($key, $defaultValue) {
    if (isset($this->configuration[$key]))
      $value = $this->configuration[$key];

    $value ??= $defaultValue;

    if (is_bool($defaultValue))
      Configuration::expectBool($key, $value);
    return $value;
  }

  public function get($key) {
    if (isset($this->configuration[$key]))
      return $this->configuration[$key];
    return null;
  }

  public function has($key): bool {
    return isset($this->configuration[$key]);
  }

  private static function expectBool($key, $value) {
    $value = filter_var($value, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);
    if (!is_bool($value)) {
      throw new Exception("$key must be boolean (1/0/true/false/on/off/yes/no). It is '$value' instead");
    }
  }

  /**
   * Create a logger
   * @param $name The name of the logger
   * @return Logger
   */
  public function createLogger($name): Logger {
    $logger = new Logger($name);
    if ($this->logHandler === 'file') {
      $logger->pushHandler(new StreamHandler($this->logFile, $this->logLevel));
    } else {
      $handler = new ErrorLogHandler(ErrorLogHandler::OPERATING_SYSTEM, $this->logLevel);
      $formatter = new LineFormatter('%channel%.%level_name%: %message% %context% %extra%');
      $handler->setFormatter($formatter);
      $logger->pushHandler($handler);
    }
    return $logger;
  }
}