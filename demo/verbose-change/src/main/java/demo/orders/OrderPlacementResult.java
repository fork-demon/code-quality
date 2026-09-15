package demo.orders;

/** Result of placing an order. */
public final class OrderPlacementResult {

  private final boolean success;
  private final Order order;

  private OrderPlacementResult(boolean success, Order order) {
    this.success = success;
    this.order = order;
  }

  /**
   * Creates a successful result.
   *
   * @param order the order
   * @return the result
   */
  public static OrderPlacementResult success(Order order) {
    return new OrderPlacementResult(true, order);
  }

  /**
   * Returns whether the placement succeeded.
   *
   * @return true if successful
   */
  public boolean isSuccess() {
    return success;
  }

  /**
   * Returns the order.
   *
   * @return the order
   */
  public Order getOrder() {
    return order;
  }
}
