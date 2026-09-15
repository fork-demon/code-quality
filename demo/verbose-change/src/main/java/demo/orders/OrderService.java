package demo.orders;

import java.util.Objects;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * Service responsible for placing orders.
 *
 * <p>This service validates the order using the configured {@link OrderValidator}, checks the
 * inventory for every line of the order, and then reserves the stock for every line of the
 * order. If any validation fails, an exception is thrown and nothing is reserved.
 */
public class OrderService {

  /** Logger for this class. */
  private static final Logger LOGGER = Logger.getLogger(OrderService.class.getName());

  /** The inventory used to check and reserve stock. */
  private final Inventory inventory;

  /** The validator used to validate orders. */
  private final OrderValidator orderValidator;

  /**
   * Creates a new OrderService with the default configuration.
   *
   * @param inventory the inventory
   */
  public OrderService(Inventory inventory) {
    this(inventory, OrderServiceConfig.builder().build());
  }

  /**
   * Creates a new OrderService.
   *
   * @param inventory the inventory
   * @param config the configuration
   */
  public OrderService(Inventory inventory, OrderServiceConfig config) {
    this.inventory = Objects.requireNonNull(inventory, "inventory must not be null");
    Objects.requireNonNull(config, "config must not be null");
    this.orderValidator = new DefaultOrderValidator(config.getMaxTotalQuantity());
  }

  /**
   * Places the given order.
   *
   * @param order the order to place
   * @return the result of the placement
   * @throws InsufficientStockException if any line exceeds available stock
   * @throws OrderLimitExceededException if the order exceeds the configured limit
   */
  public OrderPlacementResult place(Order order) {
    LOGGER.log(Level.INFO, "Placing order for customer {0}", order.customerId());
    try {
      // Validate the order
      validateOrder(order);
      // Check the stock
      checkStock(order);
      // Reserve the stock
      reserveStock(order);
      LOGGER.log(Level.INFO, "Order placed successfully for customer {0}", order.customerId());
      return OrderPlacementResult.success(order);
    } catch (InsufficientStockException | OrderLimitExceededException e) {
      LOGGER.log(Level.WARNING, "Failed to place order for customer " + order.customerId(), e);
      throw e;
    }
  }

  /**
   * Validates the order.
   *
   * @param order the order
   */
  private void validateOrder(Order order) {
    if (order == null) {
      throw new IllegalArgumentException("order must not be null");
    }
    if (order.lines() == null) {
      throw new IllegalArgumentException("order lines must not be null");
    }
    LOGGER.log(Level.FINE, "Validating order for customer {0}", order.customerId());
    orderValidator.validate(order);
  }

  /**
   * Checks that every line has sufficient stock.
   *
   * @param order the order
   */
  private void checkStock(Order order) {
    for (Order.Line line : order.lines()) {
      LOGGER.log(Level.FINE, "Checking stock for sku {0}", line.sku());
      int available = inventory.available(line.sku());
      if (!OrderValidationHelper.hasSufficientStock(line.quantity(), available)) {
        throw new InsufficientStockException(line.sku(), line.quantity(), available);
      }
    }
  }

  /**
   * Reserves the stock for every line.
   *
   * @param order the order
   */
  private void reserveStock(Order order) {
    for (Order.Line line : order.lines()) {
      LOGGER.log(Level.FINE, "Reserving {0} of sku {1}", new Object[] {line.quantity(), line.sku()});
      inventory.reserve(line.sku(), line.quantity());
    }
  }
}
