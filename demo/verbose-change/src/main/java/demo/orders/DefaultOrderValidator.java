package demo.orders;

/** Default implementation of {@link OrderValidator} that enforces the maximum total quantity. */
public class DefaultOrderValidator implements OrderValidator {

  /** The maximum total quantity allowed. */
  private final int maxTotalQuantity;

  /**
   * Creates a new DefaultOrderValidator.
   *
   * @param maxTotalQuantity the maximum total quantity
   */
  public DefaultOrderValidator(int maxTotalQuantity) {
    this.maxTotalQuantity = maxTotalQuantity;
  }

  /** {@inheritDoc} */
  @Override
  public void validate(Order order) {
    if (order == null) {
      throw new IllegalArgumentException("order must not be null");
    }
    // Calculate the total quantity of the order
    int totalQuantity = OrderValidationHelper.calculateTotalQuantity(order);
    // Check if the total quantity exceeds the maximum
    if (OrderValidationHelper.exceedsLimit(totalQuantity, maxTotalQuantity)) {
      throw new OrderLimitExceededException(totalQuantity, maxTotalQuantity);
    }
  }
}
