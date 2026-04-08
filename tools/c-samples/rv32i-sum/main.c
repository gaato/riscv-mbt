volatile int result __attribute__((section(".result"))) = 0;

static int sum_upto(int n) {
  int acc = 0;
  for (int i = 0; i <= n; i++) {
    acc += i;
  }
  return acc;
}

int main(void) {
  int x = sum_upto(10);
  result = (x == 55) ? 1 : -1;
  return result;
}
