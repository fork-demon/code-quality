package demo.orders;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

class OrderServiceTest {

  /** In-memory inventory; the reference fake for this repo. */
  static final class FakeInventory implements Inventory {
    final Map<String, Integer> stock = new HashMap<>();

    FakeInventory with(String sku, int qty) {
      stock.put(sku, qty);
      return this;
    }

    @Override
    public int available(String sku) {
      return stock.getOrDefault(sku, 0);
    }

    @Override
    public void reserve(String sku, int quantity) {
      stock.merge(sku, -quantity, Integer::sum);
    }
  }

  @Test
  void reservesEveryLineWhenStockSuffices() {
    FakeInventory inventory = new FakeInventory().with("A", 5).with("B", 2);
    OrderService service = new OrderService(inventory);

    service.place(new Order("c1", List.of(new Order.Line("A", 3), new Order.Line("B", 2))));

    assertEquals(2, inventory.available("A"));
    assertEquals(0, inventory.available("B"));
  }

  @Test
  void reservesNothingWhenAnyLineExceedsStock() {
    FakeInventory inventory = new FakeInventory().with("A", 5).with("B", 1);
    OrderService service = new OrderService(inventory);
    Order order = new Order("c1", List.of(new Order.Line("A", 3), new Order.Line("B", 2)));

    InsufficientStockException ex =
        assertThrows(InsufficientStockException.class, () -> service.place(order));

    assertEquals("sku B: requested 2, available 1", ex.getMessage());
    assertEquals(5, inventory.available("A"));
  }

  @Test
  void rejectsOrderWhenTotalExceedsLimitWithoutTouchingInventory() {
    FakeInventory inventory = new FakeInventory().with("A", 500);
    Order order = new Order("c1", List.of(new Order.Line("A", 60), new Order.Line("A", 41)));

    OrderLimitExceededException ex =
        assertThrows(OrderLimitExceededException.class, () -> new OrderService(inventory).place(order));

    assertEquals("order total 101 exceeds limit 100", ex.getMessage());
    assertEquals(500, inventory.available("A"));
  }

  @Test
  void acceptsOrderExactlyAtLimit() {
    FakeInventory inventory = new FakeInventory().with("A", 100);

    new OrderService(inventory).place(new Order("c1", List.of(new Order.Line("A", 100))));

    assertEquals(0, inventory.available("A"));
  }

  @Test
  void placesEmptyOrderWithoutTouchingInventory() {
    FakeInventory inventory = new FakeInventory().with("A", 5);

    new OrderService(inventory).place(new Order("c1", List.of()));

    assertEquals(5, inventory.available("A"));
  }
}
