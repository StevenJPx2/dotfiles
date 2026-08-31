# Examples

Before/after cases across languages and scenarios. The goal each time: turn a
dense block into 2–6 named sections separated by single blank lines.

## Python — data pipeline function

Before:
```python
def build_report(rows):
    cleaned = [r for r in rows if r.get("active")]
    total = sum(r["amount"] for r in cleaned)
    avg = total / len(cleaned) if cleaned else 0
    report = {"count": len(cleaned), "total": total, "avg": avg}
    log.info("report built: %s", report)
    return report
```

After:
```python
def build_report(rows):
    cleaned = [r for r in rows if r.get("active")]

    total = sum(r["amount"] for r in cleaned)
    avg = total / len(cleaned) if cleaned else 0

    report = {"count": len(cleaned), "total": total, "avg": avg}
    log.info("report built: %s", report)

    return report
```

Sections: **filter → compute aggregates → assemble & log → return.**

## Go — error-handling-heavy function

Dense `err` chains read better when each "do a thing, check it" pair is its own
paragraph.

Before:
```go
func saveConfig(path string, cfg Config) error {
    data, err := json.Marshal(cfg)
    if err != nil {
        return fmt.Errorf("marshal: %w", err)
    }
    f, err := os.Create(path)
    if err != nil {
        return fmt.Errorf("create: %w", err)
    }
    defer f.Close()
    if _, err := f.Write(data); err != nil {
        return fmt.Errorf("write: %w", err)
    }
    return nil
}
```

After:
```go
func saveConfig(path string, cfg Config) error {
    data, err := json.Marshal(cfg)
    if err != nil {
        return fmt.Errorf("marshal: %w", err)
    }

    f, err := os.Create(path)
    if err != nil {
        return fmt.Errorf("create: %w", err)
    }
    defer f.Close()

    if _, err := f.Write(data); err != nil {
        return fmt.Errorf("write: %w", err)
    }

    return nil
}
```

Sections: **marshal → open file → write → return.** Each block is one
operation plus its guard.

## TypeScript — multi-phase async method

Blank lines alone carry the structure; the grouping is obvious without any
labels.

```ts
async function checkout(cart: Cart, user: User): Promise<Order> {
  if (cart.items.length === 0) throw new EmptyCartError();
  const stock = await inventory.check(cart.items);
  if (!stock.ok) throw new OutOfStockError(stock.missing);

  const total = cart.items.reduce((sum, i) => sum + i.price * i.qty, 0);
  const payment = await payments.charge(user.id, total);

  const order = await orders.create({ user, cart, payment });
  await mailer.sendReceipt(user.email, order);

  return order;
}
```

Sections: **validate → charge → persist & notify → return** — each readable as a
unit purely from the spacing.

## Loop body — separate per-iteration phases

Before:
```js
for (const job of queue) {
  const start = Date.now();
  const result = run(job);
  metrics.record(job.id, Date.now() - start);
  if (result.failed) retry.push(job);
  else done.push(result);
}
```

After:
```js
for (const job of queue) {
  const start = Date.now();
  const result = run(job);

  metrics.record(job.id, Date.now() - start);

  if (result.failed) retry.push(job);
  else done.push(result);
}
```

Sections: **execute → measure → route the outcome.**

## Counter-example — do NOT over-space

Spacing every line removes the grouping signal; it is as unreadable as no
spacing.

Bad:
```js
function area(w, h) {

  const a = w * h;

  return a;

}
```

Good (trivial function, leave it dense):
```js
function area(w, h) {
  return w * h;
}
```

Rule of thumb: if you cannot label a section with a short phrase, it is not a
real section — merge it back.
