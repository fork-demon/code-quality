package demo.orders;

public class OrderLimitExceededException extends RuntimeException {
  public OrderLimitExceededException(int total, int limit) {
    super("order total " + total + " exceeds limit " + limit);
  }
}
