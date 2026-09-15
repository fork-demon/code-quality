package demo.orders;

/** Configuration for {@link OrderService}. Use {@link #builder()} to create instances. */
public final class OrderServiceConfig {

  /** The default maximum total quantity. */
  public static final int DEFAULT_MAX_TOTAL_QUANTITY = 100;

  private final int maxTotalQuantity;

  private OrderServiceConfig(Builder builder) {
    this.maxTotalQuantity = builder.maxTotalQuantity;
  }

  /**
   * Returns the maximum total quantity.
   *
   * @return the maximum total quantity
   */
  public int getMaxTotalQuantity() {
    return maxTotalQuantity;
  }

  /**
   * Creates a new builder.
   *
   * @return the builder
   */
  public static Builder builder() {
    return new Builder();
  }

  /** Builder for {@link OrderServiceConfig}. */
  public static final class Builder {
    private int maxTotalQuantity = DEFAULT_MAX_TOTAL_QUANTITY;

    private Builder() {}

    /**
     * Sets the maximum total quantity.
     *
     * @param maxTotalQuantity the maximum total quantity
     * @return this builder
     */
    public Builder maxTotalQuantity(int maxTotalQuantity) {
      this.maxTotalQuantity = maxTotalQuantity;
      return this;
    }

    /**
     * Builds the configuration.
     *
     * @return the configuration
     */
    public OrderServiceConfig build() {
      return new OrderServiceConfig(this);
    }
  }
}
