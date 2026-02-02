# TODO: Modify Order Screen for Pending Items

- [x] Add `Map<int, Map<String, dynamic>> pendingItems` to _OrderScreenState
- [x] Modify product onTap: Add to pendingItems instead of calling addProductToOrder
- [x] Update total calculation: Include pending items in totalCents
- [x] Modify cart display: Show DB lines + pending items with +/- buttons
- [x] Handle qty changes: For pending items, update the map qty
- [x] Modify _onPrintPressed: Commit pending items to DB, clear pendingItems, refresh cart
- [x] Test: Add items, total not update; press PRINTO, total updates; go back without PRINTO, total unchanged
