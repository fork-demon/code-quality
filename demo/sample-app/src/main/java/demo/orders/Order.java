package demo.orders;

import java.util.List;

/** An order as submitted by a customer. Quantities are validated by {@link OrderService}. */
public record Order(String customerId, List<Line> lines) {

  public record Line(String sku, int quantity) {}

  public int totalQuantity() {
    return lines.stream().mapToInt(Line::quantity).sum();
  }
}
