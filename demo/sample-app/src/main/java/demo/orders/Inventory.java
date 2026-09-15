package demo.orders;

/** Boundary to the stock system. */
public interface Inventory {
  int available(String sku);

  void reserve(String sku, int quantity);
}
