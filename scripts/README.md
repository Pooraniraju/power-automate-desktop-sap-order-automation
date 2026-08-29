# Scripts (reference)

`sap_va01_create_order.vbs` is a real SAP GUI Scripting routine (the same scripting API SAP itself exposes for VA01/VA02/etc.), written the way Power Automate Desktop's "Run VBScript" action calls into SAP when there's no usable API to automate against — the pattern named in the main README.

Field IDs (`wnd[0]/usr/...`) match a standard VA01 layout on a vanilla SAP GUI installation. A real engagement always starts with recording a manual VA01 entry (SAP GUI Scripting has a built-in recorder) to confirm the exact IDs and any client-specific screen variants (custom fields, extra popups) before wiring this into the desktop flow.

The `LogResult` / `LogException` / `CaptureScreenshotOnError` subs are intentionally stubs — in the actual desktop flow those responsibilities live in the surrounding Power Automate Desktop actions (Add a new row into Excel worksheet, Take screenshot), documented step by step in [`../flows/sap-order-automation-flow.md`](../flows/sap-order-automation-flow.md). They're left in the script so the success/failure control flow reads end to end on its own.
