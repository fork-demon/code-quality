package demo.orders;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoMoreInteractions;
import static org.mockito.Mockito.when;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
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

  private Inventory mockInventory;
  private OrderService service;

  @BeforeEach
  void setUp() {
    mockInventory = mock(Inventory.class);
    service = new OrderService(mockInventory);
  }

  @Test
  void testPlaceOrderSuccess() {
    when(mockInventory.available("A")).thenReturn(5);
    when(mockInventory.available("B")).thenReturn(2);
    Order order = new Order("c1", List.of(new Order.Line("A", 3), new Order.Line("B", 2)));

    OrderPlacementResult result = service.place(order);

    assertNotNull(result);
    assertTrue(result.isSuccess());
    assertEquals(order, result.getOrder());
    verify(mockInventory, times(1)).available("A");
    verify(mockInventory, times(1)).available("B");
    verify(mockInventory, times(1)).reserve("A", 3);
    verify(mockInventory, times(1)).reserve("B", 2);
    verifyNoMoreInteractions(mockInventory);
  }

  @Test
  void testPlaceOrderInsufficientStock() {
    when(mockInventory.available("A")).thenReturn(5);
    when(mockInventory.available("B")).thenReturn(1);
    Order order = new Order("c1", List.of(new Order.Line("A", 3), new Order.Line("B", 2)));

    assertThrows(InsufficientStockException.class, () -> service.place(order));

    verify(mockInventory, never()).reserve(anyString(), anyInt());
  }

  @Test
  void testPlaceOrderExceedsLimit() {
    Order order = new Order("c1", List.of(new Order.Line("A", 101)));

    assertThrows(OrderLimitExceededException.class, () -> service.place(order));
  }

  @Test
  void testPlaceOrderEmpty() {
    Order order = new Order("c1", List.of());

    assertDoesNotThrow(() -> service.place(order));
  }

  @Test
  void testValidateOrderNull() {
    assertThrows(NullPointerException.class, () -> service.place(null));
  }

  @Test
  void testConfigBuilder() {
    OrderServiceConfig config = OrderServiceConfig.builder().maxTotalQuantity(10).build();

    assertEquals(10, config.getMaxTotalQuantity());
  }

  @Test
  void testHelperExceedsLimit() {
    assertTrue(OrderValidationHelper.exceedsLimit(11, 10));
  }

  @Test
  void testFakeInventoryStillWorks() {
    FakeInventory inventory = new FakeInventory().with("A", 5);

    new OrderService(inventory).place(new Order("c1", List.of(new Order.Line("A", 5))));

    assertEquals(0, inventory.available("A"));
  }
}
