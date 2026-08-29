# Power Automate Desktop flow — action sequence (reference)

Power Automate Desktop flows are stored as an internal, GUI-authored format rather than hand-editable source, so this file documents the actual action-by-action sequence built in the desktop designer — the level of detail the README's "How it works" section summarizes. It's the reference someone would follow to rebuild the flow, and the same document I use in client handoffs alongside a recorded walkthrough.

## Trigger

- **Power Automate cloud flow** — "When a file is created" (watched SharePoint/OneDrive folder) → **Run a flow built with Power Automate Desktop** (via the on-prem/VM gateway), passing the new file's path as an input. Alternative: a **Scheduled cloud flow** that runs the same desktop flow on a timer and picks up whatever is in the folder.

## Desktop flow actions

1. **Read from Excel worksheet** — open the order-request workbook passed in from the trigger, read all rows into a datatable variable `OrderRequests` (columns: `CustomerNumber`, `MaterialNumber`, `Quantity`, `RequestedDeliveryDate`, `Plant`).
2. **Launch SAP Logon** — `Run application`, wait for the SAP Logon window, then **Attach to window** so later actions target the right session.
3. **Run VBScript** — `session = CreateObject("SAPGUI").GetScriptingEngine.Connections(0).Sessions(0)`, storing the SAP GUI Scripting session object in a PAD variable for reuse by every loop iteration.
4. **For each** `CurrentRow` in `OrderRequests`:
   1. **Run VBScript** — call `CreateSalesOrder` from [`../scripts/sap_va01_create_order.vbs`](../scripts/sap_va01_create_order.vbs), passing `CurrentRow['CustomerNumber']`, `CurrentRow['MaterialNumber']`, `CurrentRow['Quantity']`, `CurrentRow['RequestedDeliveryDate']`, `CurrentRow['Plant']`.
   2. **If** the script's return value is `True`:
      - **Add a new row into Excel worksheet** (`results.xlsx`) — `CustomerNumber`, `MaterialNumber`, `Status = "Success"`, `SalesOrderNumber`, `Timestamp`.
   3. **Else**:
      - **Take screenshot** → save to `%ResultsFolder%\errors\%CustomerNumber%_%MaterialNumber%.png`.
      - **Add a new row into Excel worksheet** (`results.xlsx`) — `CustomerNumber`, `MaterialNumber`, `Status = "Failed"`, `Reason = LastSapStatusBarText`, `Timestamp`.
      - **Continue loop** — the row-level failure does not stop the batch (see "Design choices that matter" in the main README).
5. **Close SAP Logon** — `Close window` / `Terminate process`, so the next scheduled run starts clean.
6. **Post message to Teams / Send an email** — summary built from counting `Status = Success` vs `Status = Failed` rows in `results.xlsx`: *"Processed 42 orders — 39 succeeded, 3 failed. See results.xlsx for details."*

## Selector strategy

Every SAP field reference in the VBScript uses SAP GUI Scripting's element IDs (`wnd[0]/usr/...`), which are tied to screen structure rather than pixel coordinates — the flow keeps working through window resizes or minor SAP GUI theme changes, which coordinate-based clicking does not survive.

## Error handling

Two layers, matching the README:

- **Script-level**: `On Error Resume Next` around each SAP interaction in the VBScript, so a single failed selector doesn't crash the whole script — it logs and returns `False`.
- **Flow-level**: the PAD loop's `Continue loop` on failure, plus a screenshot and the literal SAP status-bar text captured before moving to the next row — so a failure is always explainable from `results.xlsx` alone, without reopening SAP.
