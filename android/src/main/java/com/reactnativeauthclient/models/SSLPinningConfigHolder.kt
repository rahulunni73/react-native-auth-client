package com.reactnativeauthclient.models


/**
 * Holds SSL pinning configuration set by the consuming application
 * Similar to how TrustKit is configured in iOS AppDelegate
 *
 * Usage in consuming app's MainApplication.kt:
 * ```kotlin
 * override fun onCreate() {
 *     super.onCreate()
 *
 *     // Configure SSL Pinning (like iOS TrustKit in AppDelegate)
 *     val sslConfig = listOf(
 *         SSLPinningConfigHolder.PinningConfig(
 *             hostname = "app.ospyndocs.com",
 *             pins = listOf(
 *                 "CeCUJh6Dz3DoL64PbKX2KRfpIEuKqj1TEszHzQjbqok=",
 *                 "4a6cPehI7OG6cuDZka5NDZ7FR8a60d3auda+sKfg4Ng="
 *             ),
 *             includeSubdomains = true,
 *             enforcePinning = true
 *         )
 *     )
 *     SSLPinningConfigHolder.setConfig(sslConfig)
 * }
 * ```
 */
object SSLPinningConfigHolder {

  /**
   * Data class representing SSL pinning configuration for a domain
   *
   * @param hostname The domain to pin (e.g., "api.example.com")
   * @param pins List of SHA-256 public key hashes in base64 format
   * @param includeSubdomains Whether to apply pinning to subdomains (e.g., *.api.example.com)
   * @param enforcePinning Whether to enforce pinning (if false, only logs violations)
   */
  data class PinningConfig(
    val hostname: String,
    val pins: List<String>,
    val includeSubdomains: Boolean = true,
    val enforcePinning: Boolean = true
  )

  @Volatile
  private var configs: List<PinningConfig> = emptyList()

  /**
   * Set SSL pinning configuration
   * Should be called from consuming app's Application.onCreate() method
   *
   * @param configurations List of pinning configurations for different domains
   */
  @JvmStatic
  fun setConfig(configurations: List<PinningConfig>) {
    this.configs = configurations
    android.util.Log.d(
      "SSLPinningConfig",
      "✅ SSL Pinning configured for ${configurations.size} domain(s): ${configurations.map { it.hostname }}"
    )
  }

  /**
   * Get current SSL pinning configuration
   *
   * @return List of pinning configurations
   */
  @JvmStatic
  fun getConfig(): List<PinningConfig> = configs

  /**
   * Clear SSL pinning configuration
   * Useful for testing or when you want to disable SSL pinning temporarily
   */
  @JvmStatic
  fun clearConfig() {
    android.util.Log.w("SSLPinningConfig", "⚠️ Clearing SSL pinning configuration")
    configs = emptyList()
  }

  /**
   * Check if SSL pinning is configured
   *
   * @return true if at least one domain has SSL pinning configured
   */
  @JvmStatic
  fun isConfigured(): Boolean = configs.isNotEmpty()

  /**
   * Get pinning configuration for a specific hostname
   *
   * @param hostname The domain to check
   * @return PinningConfig if found, null otherwise
   */
  @JvmStatic
  fun getConfigForHost(hostname: String): PinningConfig? {
    return configs.find { it.hostname == hostname }
  }

  /**
   * Add a single pinning configuration
   * Useful if you need to add configurations dynamically
   *
   * @param config The pinning configuration to add
   */
  @JvmStatic
  fun addConfig(config: PinningConfig) {
    configs = configs + config
    android.util.Log.d(
      "SSLPinningConfig",
      "➕ Added SSL pinning for ${config.hostname}"
    )
  }

  /**
   * Remove pinning configuration for a specific hostname
   *
   * @param hostname The domain to remove pinning for
   * @return true if configuration was removed, false if not found
   */
  @JvmStatic
  fun removeConfigForHost(hostname: String): Boolean {
    val sizeBefore = configs.size
    configs = configs.filter { it.hostname != hostname }
    val removed = sizeBefore != configs.size

    if (removed) {
      android.util.Log.d(
        "SSLPinningConfig",
        "➖ Removed SSL pinning for $hostname"
      )
    }

    return removed
  }
}
