package demo.orders;

public class InsufficientStockException extends RuntimeException {
  public InsufficientStockException(String sku, int requested, int available) {
    super("sku " + sku + ": requested " + requested + ", available " + available);
  }
}
