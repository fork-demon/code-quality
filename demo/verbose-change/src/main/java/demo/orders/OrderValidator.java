package demo.orders;

/** Strategy interface for validating orders. */
public interface OrderValidator {

  /**
   * Validates the given order.
   *
   * @param order the order to validate
   * @throws OrderLimitExceededException if the order is not valid
   */
  void validate(Order order);
}
