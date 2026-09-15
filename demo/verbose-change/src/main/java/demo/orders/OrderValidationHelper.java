package demo.orders;

/** Helper methods for order validation. */
public final class OrderValidationHelper {

  private OrderValidationHelper() {
    // utility class
  }

  /**
   * Calculates the total quantity of the order.
   *
   * @param order the order
   * @return the total quantity
   */
  public static int calculateTotalQuantity(Order order) {
    if (order == null || order.lines() == null) {
      return 0;
    }
    return order.totalQuantity();
  }

  /**
   * Checks whether the total exceeds the limit.
   *
   * @param total the total
   * @param limit the limit
   * @return true if the total exceeds the limit
   */
  public static boolean exceedsLimit(int total, int limit) {
    return total > limit;
  }

  /**
   * Checks whether there is sufficient stock.
   *
   * @param requested the requested quantity
   * @param available the available quantity
   * @return true if there is sufficient stock
   */
  public static boolean hasSufficientStock(int requested, int available) {
    return requested <= available;
  }
}
