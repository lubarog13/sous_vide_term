class Utils {
  static String getTemperatureString(double temperature, bool isFahrenheit) {
    if (isFahrenheit) {
      return '${(temperature * 9 / 5 + 32).toStringAsFixed(1)} °F';
    } else {
      return '${temperature.toStringAsFixed(1)} °C';
    }
  }
}