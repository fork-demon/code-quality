package demo.orders;

/** Thrown when an order's total quantity exceeds the configured limit. */
public class OrderLimitExceededException extends RuntimeException {

  /**
   * Creates a new exception.
   *
   * @param total the total quantity
   * @param limit the limit
   */
  public OrderLimitExceededException(int total, int limit) {
    super("order total " + total + " exceeds limit " + limit);
  }
}
