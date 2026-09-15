package demo.orders;

import java.util.Objects;

/** Places orders: validates stock for every line, then reserves it. */
public class OrderService {

  private final Inventory inventory;

  public OrderService(Inventory inventory) {
    this.inventory = Objects.requireNonNull(inventory);
  }

  /**
   * Reserves stock for every line of the order.
   *
   * @throws InsufficientStockException if any line exceeds available stock; nothing is
   *     reserved in that case
   */
  public void place(Order order) {
    for (Order.Line line : order.lines()) {
      int available = inventory.available(line.sku());
      if (line.quantity() > available) {
        throw new InsufficientStockException(line.sku(), line.quantity(), available);
      }
    }
    order.lines().forEach(line -> inventory.reserve(line.sku(), line.quantity()));
  }
}
