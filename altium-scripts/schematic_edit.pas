// Schematic sheet editing for altium-mcp (single bridge command: schematic_edit)
//
// MCP / automation: Do NOT leave IDE breakpoints enabled in this project while the bridge runs.
// A paused script never writes response.json and Cursor will see TIMEOUT. Use Run without debugging
// or clear breakpoints (DXP > Run > Remove Breakpoints) before MCP calls.

function SchEditPathsEqual(const PathA, PathB: String): Boolean;
var
    NA, NB: String;
begin
    NA := Trim(LowerCase(McpNormalizeWindowsPath(PathA)));
    NB := Trim(LowerCase(McpNormalizeWindowsPath(PathB)));
    Result := AnsiCompareText(NA, NB) = 0;
end;

function SchEditParseStringAfterKey(RequestData: TStringList; const KeySub: String): String;
var
    i: Integer;
    Line: String;
begin
    Result := '';
    for i := 0 to RequestData.Count - 1 do
    begin
        Line := RequestData[i];
        if Pos(KeySub, Line) > 0 then
        begin
            Result := Trim(McpParseJSONLineValue(Line, KeySub));
            Exit;
        end;
    end;
end;

function SchEditParseFloatAfterKey(RequestData: TStringList; const KeySub: String; var Found: Boolean): Double;
var
    S: String;
begin
    Found := False;
    Result := 0;
    S := SchEditParseStringAfterKey(RequestData, KeySub);
    if S = '' then
        Exit;
    Found := True;
    Result := StrToFloat(StringReplace(S, ',', '.', MkSet(rfReplaceAll)));
end;

procedure SchEditParseStringArray(RequestData: TStringList; const ArrayKeySub: String; List: TStringList);
var
    ParamValue: String;
    i: Integer;
begin
    for i := 0 to RequestData.Count - 1 do
    begin
        if Pos(ArrayKeySub, RequestData[i]) > 0 then
        begin
            i := i + 1;
            while (i < RequestData.Count) and (Pos(']', RequestData[i]) = 0) do
            begin
                ParamValue := RequestData[i];
                ParamValue := StringReplace(ParamValue, '"', '', 1);
                ParamValue := StringReplace(ParamValue, ',', '', 1);
                ParamValue := Trim(ParamValue);
                if (ParamValue <> '') and (ParamValue <> '[') then
                    List.Add(ParamValue);
                i := i + 1;
            end;
            Break;
        end;
    end;
end;

// Returns empty string on success; otherwise ERROR: ...
function SchEditResolveSheet(ProjectFullPath, SchematicFullPath, SheetFileFilter: String;
    var SheetDiskPath: String; var SchDoc: ISch_Document): String;
var
    WS: IWorkspace;
    Project: IProject;
    Doc: IDocument;
    i, pi: Integer;
    Found: Boolean;
begin
    Result := '';
    SheetDiskPath := '';
    SchDoc := nil;

    WS := GetWorkspace;
    if WS = nil then
    begin
        Result := 'ERROR: NO_WORKSPACE';
        Exit;
    end;

    if (SchematicFullPath = '') and (SheetFileFilter = '') then
    begin
        Result := 'ERROR: SHEET_REQUIRED: pass schematic_full_path or schematic_sheet_file_name';
        Exit;
    end;

    Project := nil;

    if SchematicFullPath <> '' then
    begin
        Found := False;
        for pi := 0 to WS.DM_ProjectCount - 1 do
        begin
            Project := WS.DM_Projects(pi);
            if Project = nil then
                Continue;
            for i := 0 to Project.DM_LogicalDocumentCount - 1 do
            begin
                Doc := Project.DM_LogicalDocuments(i);
                if Doc.DM_DocumentKind <> 'SCH' then
                    Continue;
                if SchEditPathsEqual(Doc.DM_FullPath, SchematicFullPath) then
                begin
                    SheetDiskPath := Doc.DM_FullPath;
                    Found := True;
                    Break;
                end;
            end;
            if Found then
                Break;
        end;
        if not Found then
        begin
            Result := 'ERROR: SCHEMATIC_NOT_IN_OPEN_PROJECTS';
            Exit;
        end;
    end
    else if ProjectFullPath <> '' then
    begin
        for pi := 0 to WS.DM_ProjectCount - 1 do
        begin
            if (WS.DM_Projects(pi) <> nil) and SchEditPathsEqual(WS.DM_Projects(pi).DM_ProjectFullPath, ProjectFullPath) then
            begin
                Project := WS.DM_Projects(pi);
                Break;
            end;
        end;
        if Project = nil then
        begin
            Result := 'ERROR: PROJECT_NOT_FOUND';
            Exit;
        end;
        Found := False;
        for i := 0 to Project.DM_LogicalDocumentCount - 1 do
        begin
            Doc := Project.DM_LogicalDocuments(i);
            if Doc.DM_DocumentKind <> 'SCH' then
                Continue;
            if AnsiCompareText(LowerCase(ExtractFileName(Doc.DM_FullPath)), LowerCase(SheetFileFilter)) = 0 then
            begin
                SheetDiskPath := Doc.DM_FullPath;
                Found := True;
                Break;
            end;
        end;
        if not Found then
        begin
            Result := 'ERROR: SCHEMATIC_SHEET_NOT_FOUND';
            Exit;
        end;
    end
    else
    begin
        Project := WS.DM_FocusedProject;
        if Project = nil then
        begin
            Result := 'ERROR: NO_FOCUSED_PROJECT';
            Exit;
        end;
        Found := False;
        for i := 0 to Project.DM_LogicalDocumentCount - 1 do
        begin
            Doc := Project.DM_LogicalDocuments(i);
            if Doc.DM_DocumentKind <> 'SCH' then
                Continue;
            if AnsiCompareText(LowerCase(ExtractFileName(Doc.DM_FullPath)), LowerCase(SheetFileFilter)) = 0 then
            begin
                SheetDiskPath := Doc.DM_FullPath;
                Found := True;
                Break;
            end;
        end;
        if not Found then
        begin
            Result := 'ERROR: SCHEMATIC_SHEET_NOT_FOUND';
            Exit;
        end;
    end;

    Client.OpenDocument('SCH', SheetDiskPath);
    Sleep(300);
    SchDoc := SchServer.GetSchDocumentByPath(SheetDiskPath);
    if SchDoc = nil then
    begin
        Result := 'ERROR: SCH_DOCUMENT_NOT_OPEN';
        Exit;
    end;
    if SchDoc.ObjectID = eSchLib then
    begin
        Result := 'ERROR: NOT_A_SCHEMATIC_SHEET';
        Exit;
    end;
end;

function SchEditRotationFromDeg(Deg: Double): TRotationBy90;
var
    N: Integer;
begin
    N := Round(Deg / 90.0) mod 4;
    if N < 0 then
        N := N + 4;
    case N of
        0: Result := eRotate0;
        1: Result := eRotate90;
        2: Result := eRotate180;
        3: Result := eRotate270;
    else
        Result := eRotate0;
    end;
end;

function SchEditFindComponent(SchDoc: ISch_Document; const Des: String): ISch_Component;
var
    It: ISch_Iterator;
    C: ISch_Component;
begin
    Result := nil;
    if (SchDoc = nil) or (Des = '') then
        Exit;
    It := SchDoc.SchIterator_Create;
    It.AddFilter_ObjectSet(MkSet(eSchComponent));
    C := It.FirstSchObject;
    while C <> nil do
    begin
        if AnsiCompareText(Trim(C.Designator.Text), Trim(Des)) = 0 then
        begin
            Result := C;
            Break;
        end;
        C := It.NextSchObject;
    end;
    SchDoc.SchIterator_Destroy(It);
end;

function SchEditFindComponentByLibRef(SchDoc: ISch_Document; const LibRef: String): ISch_Component;
var
    It: ISch_Iterator;
    C, Last: ISch_Component;
begin
    Result := nil;
    Last := nil;
    It := SchDoc.SchIterator_Create;
    It.AddFilter_ObjectSet(MkSet(eSchComponent));
    C := It.FirstSchObject;
    while C <> nil do
    begin
        if AnsiCompareText(Trim(C.LibReference), Trim(LibRef)) = 0 then
            Last := C;
        C := It.NextSchObject;
    end;
    SchDoc.SchIterator_Destroy(It);
    Result := Last;
end;

function SchEditSetComponentTransform(SchDoc: ISch_Document; const Designator: String;
    XMils, YMils, RotDeg: Double; UseX, UseY, UseRot: Boolean): String;
var
    Comp: ISch_Component;
    Loc: TPoint;
    Props: TStringList;
begin
    Comp := SchEditFindComponent(SchDoc, Designator);
    if Comp = nil then
    begin
        Result := 'ERROR: COMPONENT_NOT_FOUND';
        Exit;
    end;
    Loc := Comp.Location;
    if UseX then
        Loc.X := MilsToCoord(XMils);
    if UseY then
        Loc.Y := MilsToCoord(YMils);
    Comp.Location := Loc;
    if UseRot then
        Comp.Orientation := SchEditRotationFromDeg(RotDeg);
    SchDoc.GraphicallyInvalidate;

    Props := TStringList.Create;
    try
        AddJSONProperty(Props, 'designator', Designator);
        AddJSONBoolean(Props, 'updated', True);
        Result := BuildJSONObject(Props);
    finally
        Props.Free;
    end;
end;

function SchEditSetComponentParameters(SchDoc: ISch_Document; const Designator: String;
    Names, Values: TStringList): String;
var
    Comp: ISch_Component;
    It: ISch_Iterator;
    P: ISch_Parameter;
    i: Integer;
    Found: Boolean;
    NewP: ISch_Parameter;
    Props: TStringList;
    Updated: Integer;
begin
    if (Names = nil) or (Values = nil) or (Names.Count <> Values.Count) or (Names.Count = 0) then
    begin
        Result := 'ERROR: PARAMETER_ARRAY_MISMATCH';
        Exit;
    end;

    Comp := SchEditFindComponent(SchDoc, Designator);
    if Comp = nil then
    begin
        Result := 'ERROR: COMPONENT_NOT_FOUND';
        Exit;
    end;

    Updated := 0;
    for i := 0 to Names.Count - 1 do
    begin
        Found := False;
        It := Comp.SchIterator_Create;
        It.AddFilter_ObjectSet(MkSet(eParameter));
        P := It.FirstSchObject;
        while P <> nil do
        begin
            if AnsiCompareText(Trim(P.Name), Trim(Names[i])) = 0 then
            begin
                P.Text := Values[i];
                Found := True;
                Inc(Updated);
                Break;
            end;
            P := It.NextSchObject;
        end;
        Comp.SchIterator_Destroy(It);

        if not Found then
        begin
            NewP := SchServer.SchObjectFactory(eParameter, eCreate_Default);
            if NewP <> nil then
            begin
                NewP.Name := Names[i];
                NewP.Text := Values[i];
                Comp.AddSchObject(NewP);
                Inc(Updated);
            end;
        end;
    end;

    SchDoc.GraphicallyInvalidate;

    Props := TStringList.Create;
    try
        AddJSONProperty(Props, 'designator', Designator);
        AddJSONInteger(Props, 'parameters_updated', Updated);
        Result := BuildJSONObject(Props);
    finally
        Props.Free;
    end;
end;

function SchEditPlaceComponent(SchDoc: ISch_Document; const LibRef, Des: String;
    XMils, YMils, RotDeg: Double; const SchLibPath: String): String;
var
    Comp: ISch_Component;
    H: TSchObjectHandle;
    Props: TStringList;
begin
    if (LibRef = '') or (Des = '') then
    begin
        Result := 'ERROR: LIB_REFERENCE_OR_DESIGNATOR_MISSING';
        Exit;
    end;

    if SchLibPath <> '' then
    begin
        if not FileExists(SchLibPath) then
        begin
            Result := 'ERROR: SCH_LIBRARY_NOT_FOUND';
            Exit;
        end;
        H := 0;
        SchDoc.PlaceSchComponent(SchLibPath, LibRef, H);
        if H = 0 then
        begin
            Result := 'ERROR: PLACE_SCH_COMPONENT_FAILED';
            Exit;
        end;
        Sleep(200);
        Comp := SchEditFindComponentByLibRef(SchDoc, LibRef);
        if Comp = nil then
        begin
            Result := 'ERROR: PLACED_COMPONENT_NOT_FOUND';
            Exit;
        end;
    end
    else
    begin
        Comp := SchServer.SchObjectFactory(eSchComponent, eCreate_Default);
        if Comp = nil then
        begin
            Result := 'ERROR: FACTORY_SCH_COMPONENT_FAILED';
            Exit;
        end;
        Comp.LibReference := LibRef;
        Comp.Designator.Text := Des;
        Comp.CurrentPartID := 1;
        Comp.Location := Point(MilsToCoord(XMils), MilsToCoord(YMils));
        Comp.Orientation := SchEditRotationFromDeg(RotDeg);
        SchDoc.RegisterSchObjectInContainer(Comp);
        SchServer.RobotManager.SendMessage(nil, c_BroadCast, SCHM_PrimitiveRegistration, Comp.I_ObjectAddress);
        if Comp = nil then
        begin
            Result := 'ERROR: FACTORY_SCH_COMPONENT_FAILED';
            Exit;
        end;
    end;

    Comp.Designator.Text := Des;
    Comp.Location := Point(MilsToCoord(XMils), MilsToCoord(YMils));
    Comp.Orientation := SchEditRotationFromDeg(RotDeg);
    SchDoc.GraphicallyInvalidate;

    Props := TStringList.Create;
    try
        AddJSONProperty(Props, 'lib_reference', LibRef);
        AddJSONProperty(Props, 'designator', Comp.Designator.Text);
        AddJSONNumber(Props, 'x_mils', XMils);
        AddJSONNumber(Props, 'y_mils', YMils);
        Result := BuildJSONObject(Props);
    finally
        Props.Free;
    end;
end;

function SchEditAddText(SchDoc: ISch_Document; const Txt: String; XMils, YMils: Double): String;
var
    L: ISch_Label;
    Props: TStringList;
begin
    if Txt = '' then
    begin
        Result := 'ERROR: TEXT_EMPTY';
        Exit;
    end;
    L := SchServer.SchObjectFactory(eLabel, eCreate_Default);
    if L = nil then
    begin
        Result := 'ERROR: FACTORY_LABEL_FAILED';
        Exit;
    end;
    L.Text := Txt;
    L.Location := Point(MilsToCoord(XMils), MilsToCoord(YMils));
    SchDoc.RegisterSchObjectInContainer(L);
    SchDoc.GraphicallyInvalidate;

    Props := TStringList.Create;
    try
        AddJSONProperty(Props, 'text', Txt);
        AddJSONNumber(Props, 'x_mils', XMils);
        AddJSONNumber(Props, 'y_mils', YMils);
        Result := BuildJSONObject(Props);
    finally
        Props.Free;
    end;
end;

function SchEditDefaultNetNameForPowerStyle(St: TPowerObjectStyle): String;
begin
    case St of
        ePowerGndPower, ePowerGndSignal, ePowerGndEarth:
            Result := 'GND';
    else
        Result := 'VCC';
    end;
end;

function SchEditPowerStyleToCanonicalString(St: TPowerObjectStyle): String;
begin
    case St of
        ePowerCircle: Result := 'circle';
        ePowerArrow: Result := 'arrow';
        ePowerBar: Result := 'bar';
        ePowerWave: Result := 'wave';
        ePowerGndPower: Result := 'gnd_power';
        ePowerGndSignal: Result := 'gnd_signal';
        ePowerGndEarth: Result := 'gnd_earth';
    else
        Result := 'arrow';
    end;
end;

// Returns True and sets St when S is a recognized style token (case-insensitive).
function SchEditTryParsePowerPortStyle(const S: String; var St: TPowerObjectStyle): Boolean;
var
    L: String;
begin
    Result := False;
    L := LowerCase(Trim(S));
    if L = 'circle' then begin St := ePowerCircle; Result := True; Exit; end;
    if L = 'arrow' then begin St := ePowerArrow; Result := True; Exit; end;
    if L = 'bar' then begin St := ePowerBar; Result := True; Exit; end;
    if L = 'wave' then begin St := ePowerWave; Result := True; Exit; end;
    if (L = 'gnd_power') or (L = 'power_ground') then begin St := ePowerGndPower; Result := True; Exit; end;
    if (L = 'gnd_signal') or (L = 'signal_ground') then begin St := ePowerGndSignal; Result := True; Exit; end;
    if (L = 'gnd_earth') or (L = 'earth') then begin St := ePowerGndEarth; Result := True; Exit; end;
end;

// Bare JSON boolean/number after key; empty -> DefaultVal.
function SchEditParseBoolWithDefault(RequestData: TStringList; const KeySub: String; DefaultVal: Boolean): Boolean;
var
    S: String;
begin
    S := Trim(SchEditParseStringAfterKey(RequestData, KeySub));
    if S = '' then
    begin
        Result := DefaultVal;
        Exit;
    end;
    S := LowerCase(S);
    if (S = 'true') or (S = '1') then
        Result := True
    else if (S = 'false') or (S = '0') then
        Result := False
    else
        Result := DefaultVal;
end;

function SchEditAddNetLabel(SchDoc: ISch_Document; const NetName: String; XMils, YMils, RotDeg: Double): String;
var
    N: ISch_NetLabel;
    Props: TStringList;
begin
    if NetName = '' then
    begin
        Result := 'ERROR: NET_NAME_EMPTY';
        Exit;
    end;
    N := SchServer.SchObjectFactory(eNetLabel, eCreate_Default);
    if N = nil then
    begin
        Result := 'ERROR: FACTORY_NETLABEL_FAILED';
        Exit;
    end;
    N.Text := NetName;
    N.Location := Point(MilsToCoord(XMils), MilsToCoord(YMils));
    N.Orientation := SchEditRotationFromDeg(RotDeg);
    SchDoc.RegisterSchObjectInContainer(N);
    SchDoc.GraphicallyInvalidate;

    Props := TStringList.Create;
    try
        AddJSONProperty(Props, 'net', NetName);
        AddJSONNumber(Props, 'x_mils', XMils);
        AddJSONNumber(Props, 'y_mils', YMils);
        Result := BuildJSONObject(Props);
    finally
        Props.Free;
    end;
end;

function SchEditPlacePowerPort(SchDoc: ISch_Document; const NetNameIn: String; XMils, YMils, RotDeg: Double;
    St: TPowerObjectStyle; ShowNet: Boolean): String;
var
    PO: ISch_PowerObject;
    Props: TStringList;
    Net: String;
    CanonStyle: String;
begin
    Net := Trim(NetNameIn);
    if Net = '' then
        Net := SchEditDefaultNetNameForPowerStyle(St);
    PO := SchServer.SchObjectFactory(ePowerObject, eCreate_Default);
    if PO = nil then
    begin
        Result := 'ERROR: FACTORY_POWER_OBJECT_FAILED';
        Exit;
    end;
    PO.Text := Net;
    PO.Location := Point(MilsToCoord(XMils), MilsToCoord(YMils));
    PO.Orientation := SchEditRotationFromDeg(RotDeg);
    PO.SetState_Style(St);
    PO.SetState_ShowNetName(ShowNet);
    SchDoc.RegisterSchObjectInContainer(PO);
    SchDoc.GraphicallyInvalidate;

    CanonStyle := SchEditPowerStyleToCanonicalString(St);
    Props := TStringList.Create;
    try
        AddJSONProperty(Props, 'net_name', Net);
        AddJSONProperty(Props, 'power_port_style', CanonStyle);
        AddJSONBoolean(Props, 'show_net_name', ShowNet);
        AddJSONNumber(Props, 'x_mils', XMils);
        AddJSONNumber(Props, 'y_mils', YMils);
        Result := BuildJSONObject(Props);
    finally
        Props.Free;
    end;
end;

// Avoid TStringList.DelimitedText (locale / StrictDelimiter quirks); split comma-separated numbers only.
procedure SchEditSplitCsvNumbers(const CSV: String; Parts: TStringList);
var
    S, Item: String;
    P: Integer;
begin
    Parts.Clear;
    S := Trim(StringReplace(StringReplace(CSV, ' ', '', MkSet(rfReplaceAll)), #9, '', MkSet(rfReplaceAll)));
    if S = '' then
        Exit;
    while S <> '' do
    begin
        P := Pos(',', S);
        if P = 0 then
        begin
            Parts.Add(Trim(S));
            Break;
        end;
        Item := Trim(Copy(S, 1, P - 1));
        Parts.Add(Item);
        Delete(S, 1, P);
    end;
end;

function SchEditTryStrToFloatToken(const Token: String; var V: Double): Boolean;
var
    T: String;
begin
    Result := False;
    T := Trim(StringReplace(Token, ',', '.', MkSet(rfReplaceAll)));
    if T = '' then
        Exit;
    try
        V := StrToFloat(T);
        Result := True;
    except
        Result := False;
    end;
end;

// Schematic wire/bus are polylines in modern AD; DelphiScript typelib often omits Corner.
// Pattern from Altium Scripting Gallery / AddWireStubsSch-Form.pas (PlaceASchWire).
procedure SchEditSetSchWireTwoVerticesMils(W: ISch_Wire; x1, y1, x2, y2: Double);
var
    P1, P2: TLocation;
begin
    P1 := Point(MilsToCoord(x1), MilsToCoord(y1));
    P2 := Point(MilsToCoord(x2), MilsToCoord(y2));
    W.Location := P1;
    W.InsertVertex := 1;
    W.SetState_Vertex(1, P1);
    W.InsertVertex := 2;
    W.SetState_Vertex(2, P2);
end;

procedure SchEditSetSchBusTwoVerticesMils(B: ISch_Bus; x1, y1, x2, y2: Double);
var
    P1, P2: TLocation;
begin
    P1 := Point(MilsToCoord(x1), MilsToCoord(y1));
    P2 := Point(MilsToCoord(x2), MilsToCoord(y2));
    B.Location := P1;
    B.InsertVertex := 1;
    B.SetState_Vertex(1, P1);
    B.InsertVertex := 2;
    B.SetState_Vertex(2, P2);
end;

// Bus entry is ISch_Line (two-point segment), not ISch_Wire polyline — see ISch_BusEntry / ISch_Line in Schematic API docs.
procedure SchEditSetSchBusEntryTwoVerticesMils(BE: ISch_BusEntry; x1, y1, x2, y2: Double);
var
    P1, P2: TLocation;
    Ln: ISch_Line;
begin
    P1 := Point(MilsToCoord(x1), MilsToCoord(y1));
    P2 := Point(MilsToCoord(x2), MilsToCoord(y2));
    Ln := BE;
    Ln.Location := P1;
    Ln.Corner := P2;
end;

// Shared orthogonal segments for eWire or eBus (same geometry as UI polylines).
function SchEditAddWireOrBusSegments(SchDoc: ISch_Document; const CSV: String; UseBus: Boolean): String;
var
    Parts: TStringList;
    i, Count: Integer;
    x1, y1, x2, y2: Double;
    W: ISch_Wire;
    Bus: ISch_Bus;
    Segments: Integer;
    Props: TStringList;
begin
    Parts := TStringList.Create;
    try
        SchEditSplitCsvNumbers(CSV, Parts);
        Count := Parts.Count;
        if Count < 4 then
        begin
            Result := 'ERROR: WIRE_POINTS_NEED_AT_LEAST_FOUR_NUMBERS';
            Exit;
        end;
        if Count mod 2 <> 0 then
        begin
            Result := 'ERROR: WIRE_POINTS_ODD_COUNT';
            Exit;
        end;

        Segments := 0;
        i := 0;
        while i < Count - 2 do
        begin
            if not SchEditTryStrToFloatToken(Parts[i], x1) or
               not SchEditTryStrToFloatToken(Parts[i + 1], y1) or
               not SchEditTryStrToFloatToken(Parts[i + 2], x2) or
               not SchEditTryStrToFloatToken(Parts[i + 3], y2) then
            begin
                Result := 'ERROR: WIRE_POINT_PARSE_FAILED';
                Exit;
            end;

            if UseBus then
            begin
                Bus := SchServer.SchObjectFactory(eBus, eCreate_Default);
                if Bus = nil then
                begin
                    Result := 'ERROR: FACTORY_BUS_FAILED';
                    Exit;
                end;
                SchEditSetSchBusTwoVerticesMils(Bus, x1, y1, x2, y2);
                SchDoc.RegisterSchObjectInContainer(Bus);
            end
            else
            begin
                W := SchServer.SchObjectFactory(eWire, eCreate_Default);
                if W = nil then
                begin
                    Result := 'ERROR: FACTORY_WIRE_FAILED';
                    Exit;
                end;
                SchEditSetSchWireTwoVerticesMils(W, x1, y1, x2, y2);
                SchDoc.RegisterSchObjectInContainer(W);
            end;
            Inc(Segments);
            i := i + 2;
        end;

        SchDoc.GraphicallyInvalidate;

        Props := TStringList.Create;
        try
            AddJSONInteger(Props, 'segments', Segments);
            Result := BuildJSONObject(Props);
        finally
            Props.Free;
        end;
    finally
        Parts.Free;
    end;
end;

function SchEditAddWireSegments(SchDoc: ISch_Document; const CSV: String): String;
begin
    Result := SchEditAddWireOrBusSegments(SchDoc, CSV, False);
end;

function SchEditAddBusSegments(SchDoc: ISch_Document; const CSV: String): String;
begin
    Result := SchEditAddWireOrBusSegments(SchDoc, CSV, True);
end;

// Single bus entry: one segment (four CSV numbers), TObjectId eBusEntry (diagonal stub).
function SchEditAddBusEntrySegment(SchDoc: ISch_Document; const CSV: String): String;
var
    Parts: TStringList;
    x1, y1, x2, y2: Double;
    BE: ISch_BusEntry;
    Props: TStringList;
begin
    Parts := TStringList.Create;
    try
        SchEditSplitCsvNumbers(CSV, Parts);
        if Parts.Count <> 4 then
        begin
            Result := 'ERROR: BUS_ENTRY_POINTS_NEED_EXACTLY_FOUR_NUMBERS';
            Exit;
        end;

        if not SchEditTryStrToFloatToken(Parts[0], x1) or
           not SchEditTryStrToFloatToken(Parts[1], y1) or
           not SchEditTryStrToFloatToken(Parts[2], x2) or
           not SchEditTryStrToFloatToken(Parts[3], y2) then
        begin
            Result := 'ERROR: BUS_ENTRY_POINT_PARSE_FAILED';
            Exit;
        end;

        BE := SchServer.SchObjectFactory(eBusEntry, eCreate_Default);
        if BE = nil then
        begin
            Result := 'ERROR: FACTORY_BUS_ENTRY_FAILED';
            Exit;
        end;
        SchEditSetSchBusEntryTwoVerticesMils(BE, x1, y1, x2, y2);
        SchDoc.RegisterSchObjectInContainer(BE);
        SchDoc.GraphicallyInvalidate;

        Props := TStringList.Create;
        try
            AddJSONInteger(Props, 'segments', 1);
            Result := BuildJSONObject(Props);
        finally
            Props.Free;
        end;
    finally
        Parts.Free;
    end;
end;

function SchematicEditMain(RequestData: TStringList): String;
var
    Action, ReportAction, SheetFilter, ProjectFullPath, SchematicFullPath: String;
    SheetPath: String;
    SchDoc: ISch_Document;
    Err: String;
    Designator, LibRef, SchLibPath, Txt, NetName, WireCSV, StyleStr: String;
    X, Y, Rot: Double;
    UseX, UseY, UseRot: Boolean;
    PStyle: TPowerObjectStyle;
    ShowNetBool: Boolean;
    Names, Values: TStringList;
    Inner: String;
    Wrap: TStringList;
begin
    Result := '';
    Inner := '';

    try
    begin
    Action := SchEditParseStringAfterKey(RequestData, '"action"');
    if Action = '' then
    begin
        Result := 'ERROR: ACTION_REQUIRED';
        Exit;
    end;

    ReportAction := Action;
    if Action = 'place_wire' then
        Action := 'add_wire'
    else if Action = 'place_net_label' then
        Action := 'add_net_label';

    SheetFilter := SchEditParseStringAfterKey(RequestData, '"schematic_sheet_file_name"');
    ProjectFullPath := SchEditParseStringAfterKey(RequestData, '"project_full_path"');
    SchematicFullPath := SchEditParseStringAfterKey(RequestData, '"schematic_full_path"');

    Err := SchEditResolveSheet(ProjectFullPath, SchematicFullPath, SheetFilter, SheetPath, SchDoc);
    if Err <> '' then
    begin
        Result := Err;
        Exit;
    end;

    if Action = 'set_component_transform' then
    begin
        Designator := SchEditParseStringAfterKey(RequestData, '"designator"');
        if Designator = '' then
        begin
            Result := 'ERROR: DESIGNATOR_REQUIRED';
            Exit;
        end;
        X := SchEditParseFloatAfterKey(RequestData, '"x_mils"', UseX);
        Y := SchEditParseFloatAfterKey(RequestData, '"y_mils"', UseY);
        Rot := SchEditParseFloatAfterKey(RequestData, '"rotation_deg"', UseRot);
        Inner := SchEditSetComponentTransform(SchDoc, Designator, X, Y, Rot, UseX, UseY, UseRot);
    end
    else if Action = 'set_component_parameters' then
    begin
        Designator := SchEditParseStringAfterKey(RequestData, '"designator"');
        if Designator = '' then
        begin
            Result := 'ERROR: DESIGNATOR_REQUIRED';
            Exit;
        end;
        Names := TStringList.Create;
        Values := TStringList.Create;
        try
            SchEditParseStringArray(RequestData, '"parameter_names"', Names);
            SchEditParseStringArray(RequestData, '"parameter_values"', Values);
            Inner := SchEditSetComponentParameters(SchDoc, Designator, Names, Values);
        finally
            Names.Free;
            Values.Free;
        end;
    end
    else if Action = 'place_component' then
    begin
        LibRef := SchEditParseStringAfterKey(RequestData, '"lib_reference"');
        Designator := SchEditParseStringAfterKey(RequestData, '"designator"');
        SchLibPath := SchEditParseStringAfterKey(RequestData, '"sch_library_path"');
        X := SchEditParseFloatAfterKey(RequestData, '"x_mils"', UseX);
        if not UseX then
            X := 0;
        Y := SchEditParseFloatAfterKey(RequestData, '"y_mils"', UseY);
        if not UseY then
            Y := 0;
        Rot := SchEditParseFloatAfterKey(RequestData, '"rotation_deg"', UseRot);
        if not UseRot then
            Rot := 0;
        Inner := SchEditPlaceComponent(SchDoc, LibRef, Designator, X, Y, Rot, SchLibPath);
    end
    else if Action = 'add_text' then
    begin
        Txt := SchEditParseStringAfterKey(RequestData, '"text"');
        X := SchEditParseFloatAfterKey(RequestData, '"x_mils"', UseX);
        Y := SchEditParseFloatAfterKey(RequestData, '"y_mils"', UseY);
        if not UseX or not UseY then
        begin
            Result := 'ERROR: X_Y_MILS_REQUIRED';
            Exit;
        end;
        Inner := SchEditAddText(SchDoc, Txt, X, Y);
    end
    else if Action = 'add_net_label' then
    begin
        NetName := SchEditParseStringAfterKey(RequestData, '"net_name"');
        X := SchEditParseFloatAfterKey(RequestData, '"x_mils"', UseX);
        Y := SchEditParseFloatAfterKey(RequestData, '"y_mils"', UseY);
        if not UseX or not UseY then
        begin
            Result := 'ERROR: X_Y_MILS_REQUIRED';
            Exit;
        end;
        Rot := SchEditParseFloatAfterKey(RequestData, '"rotation_deg"', UseRot);
        if not UseRot then
            Rot := 0;
        Inner := SchEditAddNetLabel(SchDoc, NetName, X, Y, Rot);
    end
    else if (Action = 'place_power_port') or (Action = 'place_gnd') or (Action = 'place_vcc') then
    begin
        StyleStr := SchEditParseStringAfterKey(RequestData, '"power_port_style"');
        X := SchEditParseFloatAfterKey(RequestData, '"x_mils"', UseX);
        Y := SchEditParseFloatAfterKey(RequestData, '"y_mils"', UseY);
        if not UseX or not UseY then
        begin
            Result := 'ERROR: X_Y_MILS_REQUIRED';
            Exit;
        end;
        Rot := SchEditParseFloatAfterKey(RequestData, '"rotation_deg"', UseRot);
        if not UseRot then
            Rot := 0;
        NetName := SchEditParseStringAfterKey(RequestData, '"net_name"');
        ShowNetBool := SchEditParseBoolWithDefault(RequestData, '"show_net_name"', True);

        if Action = 'place_gnd' then
        begin
            if Trim(StyleStr) = '' then
                PStyle := ePowerGndPower
            else if not SchEditTryParsePowerPortStyle(StyleStr, PStyle) then
            begin
                Result := 'ERROR: POWER_PORT_STYLE_INVALID';
                Exit;
            end;
        end
        else if Action = 'place_vcc' then
        begin
            if Trim(StyleStr) = '' then
                PStyle := ePowerArrow
            else if not SchEditTryParsePowerPortStyle(StyleStr, PStyle) then
            begin
                Result := 'ERROR: POWER_PORT_STYLE_INVALID';
                Exit;
            end;
        end
        else
        begin
            if Trim(StyleStr) = '' then
            begin
                Result := 'ERROR: POWER_PORT_STYLE_REQUIRED';
                Exit;
            end;
            if not SchEditTryParsePowerPortStyle(StyleStr, PStyle) then
            begin
                Result := 'ERROR: POWER_PORT_STYLE_INVALID';
                Exit;
            end;
        end;

        Inner := SchEditPlacePowerPort(SchDoc, NetName, X, Y, Rot, PStyle, ShowNetBool);
    end
    else if Action = 'add_wire' then
    begin
        WireCSV := SchEditParseStringAfterKey(RequestData, '"wire_points_csv"');
        if WireCSV = '' then
        begin
            Result := 'ERROR: WIRE_POINTS_CSV_REQUIRED';
            Exit;
        end;
        Inner := SchEditAddWireSegments(SchDoc, WireCSV);
    end
    else if Action = 'add_bus' then
    begin
        WireCSV := SchEditParseStringAfterKey(RequestData, '"wire_points_csv"');
        if WireCSV = '' then
        begin
            Result := 'ERROR: BUS_POINTS_CSV_REQUIRED';
            Exit;
        end;
        Inner := SchEditAddBusSegments(SchDoc, WireCSV);
    end
    else if Action = 'add_bus_entry' then
    begin
        WireCSV := SchEditParseStringAfterKey(RequestData, '"wire_points_csv"');
        if WireCSV = '' then
        begin
            Result := 'ERROR: BUS_ENTRY_POINTS_CSV_REQUIRED';
            Exit;
        end;
        Inner := SchEditAddBusEntrySegment(SchDoc, WireCSV);
    end
    else
    begin
        Result := 'ERROR: UNKNOWN_ACTION';
        Exit;
    end;

    if Pos('ERROR:', Inner) = 1 then
    begin
        Result := Inner;
        Exit;
    end;

    Wrap := TStringList.Create;
    try
        AddJSONProperty(Wrap, 'action', ReportAction);
        AddJSONProperty(Wrap, 'sheet', SheetPath);
        Wrap.Add('"details": ' + Inner);
        Result := BuildJSONObject(Wrap);
    finally
        Wrap.Free;
    end;
    end;

    except
        Result := 'ERROR: SCHEMATIC_EDIT_EXCEPTION';
    end;
end;
