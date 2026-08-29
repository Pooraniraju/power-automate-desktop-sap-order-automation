' ============================================================================
' sap_va01_create_order.vbs
'
' Reference SAP GUI Scripting routine for creating a sales order via VA01.
' This is the automation logic that the Power Automate Desktop flow
' (see ../flows/sap-order-automation-flow.md) invokes for each row of the
' input file via "Run SAP GUI script" / a Run VBScript action.
'
' Reference build for portfolio purposes -- screen field names below match a
' standard SAP GUI VA01 layout; connection details, order types and sales
' org/plant codes are illustrative and should be replaced with a real
' client's configuration.
' ============================================================================

Function CreateSalesOrder(orderType, soldToParty, materialNumber, orderQuantity, requestedDeliveryDate, plant)
    ' Expects an existing SAP GUI Scripting session in the global variable "session"
    ' (established by the caller after SAPGUI.exe / SAP Logon has connected).

    On Error Resume Next

    Dim statusText
    CreateSalesOrder = False

    session.findById("wnd[0]").maximize
    session.findById("wnd[0]/tbar[0]/okcd").text = "/nva01"
    session.StartTransaction "VA01"

    ' --- Initial screen: order type and org data ---
    session.findById("wnd[0]/usr/ctxtVBAK-AUART").text = orderType
    session.findById("wnd[0]/usr/ctxtVBAK-VKORG").text = "1000"   ' Sales org (sample)
    session.findById("wnd[0]/usr/ctxtVBAK-VTWEG").text = "10"     ' Distribution channel (sample)
    session.findById("wnd[0]/usr/ctxtVBAK-SPART").text = "00"     ' Division (sample)
    session.findById("wnd[0]/tbar[1]/btn[0]").press           ' Enter

    If Err.Number <> 0 Then
        LogException "Initial screen entry failed", orderType & "/" & soldToParty, Err.Description
        Err.Clear
        Exit Function
    End If

    ' --- Header data: sold-to party, requested delivery date ---
    session.findById("wnd[0]/usr/subSUBSCREEN_HEADER:SAPMV45A:4021/txtKUAGV-KUNNR").text = soldToParty
    session.findById("wnd[0]/usr/subSUBSCREEN_HEADER:SAPMV45A:4021/ctxtVBKD-BSTDK").text = requestedDeliveryDate
    session.findById("wnd[0]/tbar[1]/btn[0]").press           ' Enter, confirm partner determination

    ' Dismiss any informational popups (e.g. credit check / pricing info) that
    ' would otherwise block the line-item screen.
    DismissInfoPopupIfPresent

    ' --- Line item: material, quantity, plant ---
    session.findById("wnd[0]/usr/tblSAPMV45ATCTRL_UEBERSICHT/ctxtRV45A-MABNR[1,0]").text = materialNumber
    session.findById("wnd[0]/usr/tblSAPMV45ATCTRL_UEBERSICHT/txtRV45A-KWMENG[3,0]").text = orderQuantity
    session.findById("wnd[0]/usr/tblSAPMV45ATCTRL_UEBERSICHT/ctxtVBAP-WERKS[6,0]").text = plant
    session.findById("wnd[0]/tbar[1]/btn[0]").press           ' Enter, price the line

    If Err.Number <> 0 Then
        LogException "Line item entry failed", materialNumber, Err.Description
        Err.Clear
        Exit Function
    End If

    DismissInfoPopupIfPresent

    ' --- Save and read the status bar instead of assuming success ---
    session.findById("wnd[0]/tbar[0]/btn[11]").press           ' Save
    statusText = session.findById("wnd[0]/sbar").Text

    If InStr(statusText, "has been saved") > 0 Then
        ' Status bar messages look like: "Standard Order 0004500123 has been saved"
        Dim orderNumber
        orderNumber = ExtractOrderNumber(statusText)
        LogResult "Success", orderNumber, statusText, soldToParty, materialNumber
        CreateSalesOrder = True
    Else
        ' Business-rule error (credit block, material not found, incomplete
        ' data, etc.) -- capture the exact SAP message and a screenshot, then
        ' let the caller move on to the next row instead of aborting the batch.
        CaptureScreenshotOnError soldToParty & "_" & materialNumber
        LogException "Save rejected by SAP", soldToParty & "/" & materialNumber, statusText
    End If

End Function

Sub DismissInfoPopupIfPresent()
    ' VA01 frequently raises modal popups (pricing/credit information,
    ' incomplete-data warnings). If wnd[1] exists, acknowledge it with Enter
    ' rather than letting it block the next selector call.
    On Error Resume Next
    If Not session.findById("wnd[1]", False) Is Nothing Then
        session.findById("wnd[1]/tbar[0]/btn[0]").press
    End If
    Err.Clear
End Sub

Function ExtractOrderNumber(statusText)
    ' Pulls the numeric sales order number out of a status bar message such as
    ' "Standard Order 0004500123 has been saved".
    Dim parts, i, token
    parts = Split(statusText, " ")
    For i = 0 To UBound(parts)
        token = parts(i)
        If Len(token) >= 8 And IsNumeric(token) Then
            ExtractOrderNumber = token
            Exit Function
        End If
    Next
    ExtractOrderNumber = ""
End Function

Sub LogResult(status, orderNumber, message, soldToParty, materialNumber)
    ' In the actual flow this call is replaced by the PAD "Write to CSV" /
    ' "Add a new row into Excel worksheet" action described in
    ' ../flows/sap-order-automation-flow.md (step 6, Reconciliation).
    ' Kept here as a stub so this script is self-documenting on its own.
End Sub

Sub LogException(stage, context, message)
    ' Stub -- see LogResult. In production this writes one row per failure to
    ' the results file/Dataverse table with Status = Failed and the reason.
End Sub

Sub CaptureScreenshotOnError(fileNameHint)
    ' Stub -- the PAD flow's "Take screenshot" action is responsible for this;
    ' kept here so the failure path in this script is easy to follow end to end.
End Sub
