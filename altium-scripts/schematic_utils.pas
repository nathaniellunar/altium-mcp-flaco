// Helper function to convert string to pin electrical type
function StrToPinElectricalType(ElecType: String): TPinElectrical;
begin
    if ElecType = 'eElectricHiZ' then
        Result := eElectricHiZ
    else if ElecType = 'eElectricInput' then
        Result := eElectricInput
    else if ElecType = 'eElectricIO' then
        Result := eElectricIO
    else if ElecType = 'eElectricOpenCollector' then
        Result := eElectricOpenCollector
    else if ElecType = 'eElectricOpenEmitter' then
        Result := eElectricOpenEmitter
    else if ElecType = 'eElectricOutput' then
        Result := eElectricOutput
    else if ElecType = 'eElectricPassive' then
        Result := eElectricPassive
    else if ElecType = 'eElectricPower' then
        Result := eElectricPower
    else
        Result := eElectricPassive; // Default
end;

// Helper function to convert string to pin orientation
function StrToPinOrientation(Orient: String): TRotationBy90;
begin
    if Orient = 'eRotate0' then
        Result := eRotate0
    else if Orient = 'eRotate90' then
        Result := eRotate90
    else if Orient = 'eRotate180' then
        Result := eRotate180
    else if Orient = 'eRotate270' then
        Result := eRotate270
    else
        Result := eRotate0; // Default
end;

// Function to get current schematic library component data
function GetLibrarySymbolReference(ROOT_DIR: String): String;
var
    CurrentLib       : ISch_Lib;
    SchComponent     : ISch_Component;
    PinIterator      : ISch_Iterator;
    Pin              : ISch_Pin;
    ComponentProps   : TStringList;
    PinsArray        : TStringList;
    PinProps         : TStringList;
    OutputLines      : TStringList;
    PinName, PinNum  : String;
    PinType          : String;
    PinOrient        : String;
    PinX, PinY       : Integer;
begin
    Result := '';
    
    // Check if we have a schematic library document
    CurrentLib := SchServer.GetCurrentSchDocument;
    if (CurrentLib.ObjectID <> eSchLib) Then
    begin
        Result := 'ERROR: Please open a schematic library document';
        Exit;
    end;
    
    // Get the currently focused component from the library
    SchComponent := CurrentLib.CurrentSchComponent;
    if SchComponent = Nil Then
    begin
        Result := 'ERROR: No component is currently selected in the library';
        Exit;
    end;
    
    // Create component properties
    ComponentProps := TStringList.Create;
    
    try
        // Add basic component properties
        AddJSONProperty(ComponentProps, 'library_name', ExtractFileName(CurrentLib.DocumentName));
        AddJSONProperty(ComponentProps, 'component_name', SchComponent.LibReference);
        AddJSONProperty(ComponentProps, 'description', SchComponent.ComponentDescription);
        AddJSONProperty(ComponentProps, 'designator', SchComponent.Designator.Text);
        AddJSONInteger(ComponentProps, 'part_count', SchComponent.PartCount);

        // Create an array for pins
        PinsArray := TStringList.Create;
        
        try
            // Create pin iterator
            PinIterator := SchComponent.SchIterator_Create;
            PinIterator.AddFilter_ObjectSet(MkSet(ePin));
            
            Pin := PinIterator.FirstSchObject;
            
            // Process all pins
            while (Pin <> nil) do
            begin
                // Create pin properties
                PinProps := TStringList.Create;
                
                try
                    // Get pin properties
                    PinNum := Pin.Designator;
                    PinName := Pin.Name;
                    
                    // Convert electrical type to string
                    case Pin.Electrical of
                        eElectricHiZ: PinType := 'eElectricHiZ';
                        eElectricInput: PinType := 'eElectricInput';
                        eElectricIO: PinType := 'eElectricIO';
                        eElectricOpenCollector: PinType := 'eElectricOpenCollector';
                        eElectricOpenEmitter: PinType := 'eElectricOpenEmitter';
                        eElectricOutput: PinType := 'eElectricOutput';
                        eElectricPassive: PinType := 'eElectricPassive';
                        eElectricPower: PinType := 'eElectricPower';
                        else PinType := 'eElectricPassive';
                    end;
                    
                    // Convert orientation to string
                    case Pin.Orientation of
                        eRotate0: PinOrient := 'eRotate0';
                        eRotate90: PinOrient := 'eRotate90';
                        eRotate180: PinOrient := 'eRotate180';
                        eRotate270: PinOrient := 'eRotate270';
                        else PinOrient := 'eRotate0';
                    end;
                    
                    // Get coordinates
                    PinX := CoordToMils(Pin.Location.X);
                    PinY := CoordToMils(Pin.Location.Y);
                    
                    // Add pin properties
                    AddJSONProperty(PinProps, 'pin_number', PinNum);
                    AddJSONProperty(PinProps, 'pin_name', PinName);
                    AddJSONProperty(PinProps, 'pin_type', PinType);
                    AddJSONProperty(PinProps, 'pin_orientation', PinOrient);
                    AddJSONNumber(PinProps, 'x', PinX);
                    AddJSONNumber(PinProps, 'y', PinY);
                    AddJSONInteger(PinProps, 'owner_part_id', Pin.OwnerPartId);

                    // Add this pin to the pins array
                    PinsArray.Add(BuildJSONObject(PinProps, 1));
                    
                    // Move to next pin
                    Pin := PinIterator.NextSchObject;
                finally
                    PinProps.Free;
                end;
            end;
            
            SchComponent.SchIterator_Destroy(PinIterator);
            
            // Add pins array to component - pass empty string as the array name
            // because we're adding it directly to the ComponentProps
            ComponentProps.Add('"pins": ' + BuildJSONArray(PinsArray));
            
            // Build final JSON
            OutputLines := TStringList.Create;
            
            try
                OutputLines.Text := BuildJSONObject(ComponentProps);
                Result := WriteJSONToFile(OutputLines, ROOT_DIR+'temp_symbol_reference.json');
            finally
                OutputLines.Free;
            end;
        finally
            PinsArray.Free;
        end;
    finally
        ComponentProps.Free;
    end;
end;

function CreateSchematicSymbol(SymbolName: String; PinsList: TStringList; PartCount: Integer = 1): String;
var
    CurrentLib       : ISch_Lib;
    SchComponent     : ISch_Component;
    SchPin           : ISch_Pin;
    R                : ISch_Rectangle;
    I, J, PinCount   : Integer;
    PinData          : TStringList;
    PinName, PinNum  : String;
    PinType          : String;
    PinOrient        : String;
    PinX, PinY       : Integer;
    PinOwnerPartId   : Integer;
    PinElec          : TPinElectrical;
    PinOrientation   : TRotationBy90;
    MinX, MaxX, MinY, MaxY : Integer;
    HasPins          : Boolean;
    ResultProps      : TStringList;
    Description      : String;
    OutputLines      : TStringList;
begin
    // Check if we have a schematic library document
    CurrentLib := SchServer.GetCurrentSchDocument;
    if (CurrentLib.ObjectID <> eSchLib) Then
    begin
        Result := 'ERROR: Please open a schematic library document';
        Exit;
    end;

    Description := 'New Component';  // Default description

    // Parse the pins list for description and auto-detect PartCount from max owner_part_id
    for I := 0 to PinsList.Count - 1 do
    begin
        if (Pos('Description=', PinsList[I]) = 1) then
        begin
            Description := Copy(PinsList[I], 13, Length(PinsList[I]) - 12);
        end
        else
        begin
            // Check for owner_part_id in pin data to auto-detect PartCount
            PinData := TStringList.Create;
            try
                PinData.Delimiter := '|';
                PinData.DelimitedText := PinsList[I];
                if (PinData.Count >= 7) then
                begin
                    PinOwnerPartId := StrToInt(PinData[6]);
                    if (PinOwnerPartId > PartCount) then
                        PartCount := PinOwnerPartId;
                end;
            finally
                PinData.Free;
            end;
        end;
    end;

    // Create a library component (a page of the library is created)
    SchComponent := SchServer.SchObjectFactory(eSchComponent, eCreate_Default);
    if (SchComponent = Nil) Then
    begin
        Result := 'ERROR: Failed to create component';
        Exit;
    end;

    // Set up parameters for the library component
    SchComponent.CurrentPartID := 1;
    SchComponent.DisplayMode := 0;
    SchComponent.PartCount := PartCount;

    // Define the LibReference and component description
    SchComponent.LibReference := SymbolName;
    SchComponent.ComponentDescription := Description;
    SchComponent.Designator.Text := 'U?';

    // Create a body rectangle for each part
    PinCount := 0;
    for J := 1 to PartCount do
    begin
        // Compute bounding box for this part's pins (including shared pins with OwnerPartId=0)
        MinX := 9999; MaxX := -9999; MinY := 9999; MaxY := -9999;
        HasPins := False;

        for I := 0 to PinsList.Count - 1 do
        begin
            if (Pos('Description=', PinsList[I]) = 1) then Continue;

            PinData := TStringList.Create;
            try
                PinData.Delimiter := '|';
                PinData.DelimitedText := PinsList[I];

                if (PinData.Count >= 6) then
                begin
                    PinX := StrToInt(PinData[4]);
                    PinY := StrToInt(PinData[5]);

                    // Determine owner part id (default 1 for backward compatibility)
                    if (PinData.Count >= 7) then
                        PinOwnerPartId := StrToInt(PinData[6])
                    else
                        PinOwnerPartId := 1;

                    // Include pin in this part's bounding box if it belongs to this part or is shared (0)
                    if (PinOwnerPartId = J) or (PinOwnerPartId = 0) then
                    begin
                        MinX := Min(MinX, PinX);
                        MaxX := Max(MaxX, PinX);
                        MinY := Min(MinY, PinY);
                        MaxY := Max(MaxY, PinY);
                        HasPins := True;
                    end;
                end;
            finally
                PinData.Free;
            end;
        end;

        // Default rectangle if no pins for this part
        if not HasPins then
        begin
            MinX := 300; MinY := 0; MaxX := 1000; MaxY := 1000;
        end;

        // Create a rectangle for this part's body
        R := SchServer.SchObjectFactory(eRectangle, eCreate_Default);
        if (R <> Nil) Then
        begin
            R.LineWidth := eSmall;
            R.Location := Point(MilsToCoord(MinX), MilsToCoord(MinY - 100));
            R.Corner := Point(MilsToCoord(MaxX), MilsToCoord(MaxY + 100));
            R.AreaColor := $00B0FFFF; // Yellow (BGR format)
            R.Color := $00FF0000;     // Blue (BGR format)
            R.IsSolid := True;
            R.OwnerPartId := J;
            R.OwnerPartDisplayMode := 0;
            SchComponent.AddSchObject(R);
        end;

        // Position designator using Part 1's bounding box
        if (J = 1) then
            SchComponent.Designator.Location := Point(MilsToCoord(MinX), MilsToCoord(MaxY + 100));
    end;

    // Add pins to the component
    for I := 0 to PinsList.Count - 1 do
    begin
        if (Pos('Description=', PinsList[I]) = 1) then Continue;

        PinData := TStringList.Create;
        try
            PinData.Delimiter := '|';
            PinData.DelimitedText := PinsList[I];

            if (PinData.Count >= 6) then
            begin
                PinNum := PinData[0];
                PinName := PinData[1];
                PinType := PinData[2];
                PinOrient := PinData[3];
                PinX := StrToInt(PinData[4]);
                PinY := StrToInt(PinData[5]);

                // Determine owner part id (default 1 for backward compatibility)
                if (PinData.Count >= 7) then
                    PinOwnerPartId := StrToInt(PinData[6])
                else
                    PinOwnerPartId := 1;

                // Create a pin
                SchPin := SchServer.SchObjectFactory(ePin, eCreate_Default);
                if (SchPin = Nil) Then
                    Continue;

                // Set pin properties
                PinElec := StrToPinElectricalType(PinType);
                PinOrientation := StrToPinOrientation(PinOrient);

                SchPin.Designator := PinNum;
                SchPin.Name := PinName;
                SchPin.Electrical := PinElec;
                SchPin.Orientation := PinOrientation;
                SchPin.Location := Point(MilsToCoord(PinX), MilsToCoord(PinY));

                // Set ownership to the specified part (0 = shared across all parts)
                SchPin.OwnerPartId := PinOwnerPartId;
                SchPin.OwnerPartDisplayMode := 0;

                SchComponent.AddSchObject(SchPin);
                PinCount := PinCount + 1;
            end;
        finally
            PinData.Free;
        end;
    end;

    // Add the component to the library
    CurrentLib.AddSchComponent(SchComponent);

    // Send a system notification that a new component has been added to the library
    SchServer.RobotManager.SendMessage(nil, c_BroadCast, SCHM_PrimitiveRegistration, SchComponent.I_ObjectAddress);
    CurrentLib.CurrentSchComponent := SchComponent;

    // Refresh library
    CurrentLib.GraphicallyInvalidate;

    // Create result JSON
    ResultProps := TStringList.Create;
    try
        AddJSONBoolean(ResultProps, 'success', True);
        AddJSONProperty(ResultProps, 'component_name', SymbolName);
        AddJSONInteger(ResultProps, 'pins_count', PinCount);
        AddJSONInteger(ResultProps, 'part_count', PartCount);

        // Build final JSON
        OutputLines := TStringList.Create;
        try
            OutputLines.Text := BuildJSONObject(ResultProps);
            Result := OutputLines.Text;
        finally
            OutputLines.Free;
        end;
    finally
        ResultProps.Free;
    end;
end;

// Function to search for a symbol in a schematic library and navigate to it
function SearchLibrarySymbol(ROOT_DIR: String; LibraryPath: String; SymbolName: String): String;
var
    CurrentLib       : ISch_Lib;
    LibIterator      : ISch_Iterator;
    LibComp          : ISch_Component;
    MatchedComp      : ISch_Component;
    ResultProps      : TStringList;
    MatchesArray     : TStringList;
    AllSymbolsArray  : TStringList;
    MatchProps       : TStringList;
    OutputLines      : TStringList;
    SearchUpper      : String;
    LibRefUpper      : String;
    MatchCount       : Integer;
    ServerDoc        : IServerDocument;
    OpenDlg          : TOpenDialog;
    NeedToOpen       : Boolean;
begin
    Result := '';
    MatchedComp := Nil;
    MatchCount := 0;
    SearchUpper := UpperCase(SymbolName);
    NeedToOpen := False;

    // If a library path is provided, open it
    if (LibraryPath <> '') then
    begin
        NeedToOpen := True;
    end
    else
    begin
        // No path provided - check if a SchLib is already open
        if (SchServer <> Nil) then
        begin
            CurrentLib := SchServer.GetCurrentSchDocument;
            if (CurrentLib <> Nil) and (CurrentLib.ObjectID = eSchLib) then
                NeedToOpen := False  // Already have a SchLib open
            else
                NeedToOpen := True;  // No SchLib open, need to browse
        end
        else
            NeedToOpen := True;
    end;

    // If we need to open a library and no path was given, prompt the user
    if NeedToOpen and (LibraryPath = '') then
    begin
        OpenDlg := TOpenDialog.Create(nil);
        try
            OpenDlg.Title := 'Select Schematic Library (.SchLib)';
            OpenDlg.Filter := 'Schematic Library (*.SchLib)|*.SchLib|All Files (*.*)|*.*';
            OpenDlg.FilterIndex := 1;
            if OpenDlg.Execute then
                LibraryPath := OpenDlg.FileName
            else
            begin
                Result := 'ERROR: No library selected. User cancelled the file browser.';
                Exit;
            end;
        finally
            OpenDlg.Free;
        end;
    end;

    // Open the library if we have a path
    if (LibraryPath <> '') then
    begin
        // Check if the file exists
        if not FileExists(LibraryPath) then
        begin
            Result := 'ERROR: Library file not found: ' + LibraryPath;
            Exit;
        end;

        // Open the library document
        ServerDoc := Client.OpenDocument('SchLib', LibraryPath);
        if ServerDoc = Nil then
        begin
            Result := 'ERROR: Failed to open library: ' + LibraryPath;
            Exit;
        end;
        Client.ShowDocument(ServerDoc);
        Sleep(500); // Give Altium time to focus the document
    end;

    // Get the current schematic library document
    CurrentLib := SchServer.GetCurrentSchDocument;
    if CurrentLib = Nil then
    begin
        Result := 'ERROR: No schematic library document is currently open';
        Exit;
    end;

    if (CurrentLib.ObjectID <> eSchLib) then
    begin
        Result := 'ERROR: Current document is not a schematic library. Please open a .SchLib file';
        Exit;
    end;

    // Create arrays for results
    MatchesArray := TStringList.Create;
    AllSymbolsArray := TStringList.Create;
    ResultProps := TStringList.Create;

    try
        // Create library iterator to enumerate all symbols
        // NOTE: Must use SchLibIterator_Create (not SchIterator_Create) for SchLib documents
        LibIterator := CurrentLib.SchLibIterator_Create;
        LibIterator.AddFilter_ObjectSet(MkSet(eSchComponent));

        LibComp := LibIterator.FirstSchObject;
        while (LibComp <> Nil) do
        begin
            LibRefUpper := UpperCase(LibComp.LibReference);

            // Add to all symbols list
            AllSymbolsArray.Add('"' + LibComp.LibReference + '"');

            // Check for partial match
            if (Pos(SearchUpper, LibRefUpper) > 0) then
            begin
                MatchCount := MatchCount + 1;

                // Record this match
                MatchProps := TStringList.Create;
                try
                    AddJSONProperty(MatchProps, 'name', LibComp.LibReference);
                    AddJSONProperty(MatchProps, 'description', LibComp.ComponentDescription);

                    // Check for exact match
                    if (LibRefUpper = SearchUpper) then
                        AddJSONBoolean(MatchProps, 'exact_match', True)
                    else
                        AddJSONBoolean(MatchProps, 'exact_match', False);

                    MatchesArray.Add(BuildJSONObject(MatchProps, 1));
                finally
                    MatchProps.Free;
                end;

                // Prefer exact match, otherwise use first partial match
                if (LibRefUpper = SearchUpper) then
                    MatchedComp := LibComp
                else if (MatchedComp = Nil) then
                    MatchedComp := LibComp;
            end;

            LibComp := LibIterator.NextSchObject;
        end;

        CurrentLib.SchIterator_Destroy(LibIterator);

        // Navigate to the matched component if found
        if (MatchedComp <> Nil) then
        begin
            CurrentLib.CurrentSchComponent := MatchedComp;
            CurrentLib.GraphicallyInvalidate;

            AddJSONBoolean(ResultProps, 'found', True);
            AddJSONProperty(ResultProps, 'navigated_to', MatchedComp.LibReference);
            AddJSONProperty(ResultProps, 'description', MatchedComp.ComponentDescription);
        end
        else
        begin
            AddJSONBoolean(ResultProps, 'found', False);
            AddJSONProperty(ResultProps, 'message', 'No symbol matching "' + SymbolName + '" was found');
        end;

        AddJSONInteger(ResultProps, 'match_count', MatchCount);
        AddJSONProperty(ResultProps, 'library_name', ExtractFileName(CurrentLib.DocumentName));
        AddJSONInteger(ResultProps, 'total_symbols', AllSymbolsArray.Count);
        ResultProps.Add('"matches": ' + BuildJSONArray(MatchesArray));

        // Build final JSON
        OutputLines := TStringList.Create;
        try
            OutputLines.Text := BuildJSONObject(ResultProps);
            Result := WriteJSONToFile(OutputLines, ROOT_DIR + 'temp_search_symbol.json');
        finally
            OutputLines.Free;
        end;
    finally
        MatchesArray.Free;
        AllSymbolsArray.Free;
        ResultProps.Free;
    end;
end;

// Collapse JSON/Windows path quirks so comparisons match Altium DM_* paths (loaded before json_utils).
function McpNormalizeWindowsPath(const S: String): String;
var
    T, Prev: String;
    IsUnc: Boolean;
begin
    T := Trim(StringReplace(S, '/', '\', MkSet(rfReplaceAll)));
    if T = '' then
    begin
        Result := '';
        Exit;
    end;
    IsUnc := (Length(T) >= 2) and (T[1] = '\') and (T[2] = '\');
    if IsUnc then
    begin
        Delete(T, 1, 2);
        repeat
            Prev := T;
            T := StringReplace(T, '\\', '\', MkSet(rfReplaceAll));
        until T = Prev;
        Result := '\\' + T;
    end
    else
    begin
        repeat
            Prev := T;
            T := StringReplace(T, '\\', '\', MkSet(rfReplaceAll));
        until T = Prev;
        Result := T;
    end;
end;

// Read one JSON string or bare token from a single pretty-printed request.json line after KeySub.
function McpParseJSONLineValue(const Line, KeySub: String): String;
var
    KeyPos, ColonPos, i, LenLine: Integer;
    OutStr, Tail: String;
begin
    Result := '';
    KeyPos := Pos(KeySub, Line);
    if KeyPos = 0 then
        Exit;
    ColonPos := 0;
    for i := KeyPos + Length(KeySub) to Length(Line) do
        if Line[i] = ':' then
        begin
            ColonPos := i;
            Break;
        end;
    if ColonPos = 0 then
        Exit;
    i := ColonPos + 1;
    LenLine := Length(Line);
    while (i <= LenLine) and (Line[i] <= #32) do
        Inc(i);
    if i > LenLine then
        Exit;
    if Line[i] = '"' then
    begin
        Inc(i);
        OutStr := '';
        while i <= LenLine do
        begin
            if Line[i] = '\' then
            begin
                Inc(i);
                if i > LenLine then
                    Break;
                case Line[i] of
                    '\', '"':
                        OutStr := OutStr + Line[i];
                    'n':
                        OutStr := OutStr + #10;
                    'r':
                        OutStr := OutStr + #13;
                    't':
                        OutStr := OutStr + #9;
                else
                    OutStr := OutStr + Line[i];
                end;
                Inc(i);
            end
            else if Line[i] = '"' then
                Break
            else
            begin
                OutStr := OutStr + Line[i];
                Inc(i);
            end;
        end;
        Result := OutStr;
        Exit;
    end;
    Tail := Copy(Line, i, LenLine - i + 1);
    Tail := Trim(Tail);
    while (Length(Tail) > 0) and (Tail[Length(Tail)] = ',') do
        SetLength(Tail, Length(Tail) - 1);
    Result := Trim(Tail);
end;

// Parse a JSON string array from pretty-printed request (same pattern as schematic_edit).
procedure SchDataParseStringArray(RequestData: TStringList; const ArrayKeySub: String; List: TStringList);
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

type
    TSchMcpInclude = record
        WantSheet: Boolean;
        WantComponents: Boolean;
        WantWires: Boolean;
        WantBuses: Boolean;
        WantNetLabels: Boolean;
        WantPowerPorts: Boolean;
        WantTextLabels: Boolean;
        WantJunctions: Boolean;
        WantPorts: Boolean;
        WantOffSheetConnectors: Boolean;
        WantSheetSymbols: Boolean;
        WantDirectives: Boolean;
        WantFigures: Boolean;
        WantHarness: Boolean;
        WantDrawingObjects: Boolean;
    end;

const
    SCH_DRAW_FILTER_WIRES = 1;
    SCH_DRAW_FILTER_BUSES = 2;
    SCH_DRAW_FILTER_NETLABELS = 3;
    SCH_DRAW_FILTER_POWER = 4;
    SCH_DRAW_FILTER_TEXT = 5;
    SCH_DRAW_FILTER_JUNCTIONS = 6;
    SCH_DRAW_FILTER_PORTS = 7;
    SCH_DRAW_FILTER_OFFSHEET = 8;
    SCH_DRAW_FILTER_SHEETSYM = 9;
    SCH_DRAW_FILTER_DIRECTIVES = 10;
    SCH_DRAW_FILTER_FIGURES = 11;

procedure SchMcpSetAllIncludes(var F: TSchMcpInclude);
begin
    F.WantSheet := True;
    F.WantComponents := True;
    F.WantWires := True;
    F.WantBuses := True;
    F.WantNetLabels := True;
    F.WantPowerPorts := True;
    F.WantTextLabels := True;
    F.WantJunctions := True;
    F.WantPorts := True;
    F.WantOffSheetConnectors := True;
    F.WantSheetSymbols := True;
    F.WantDirectives := True;
    F.WantFigures := True;
    F.WantHarness := True;
    F.WantDrawingObjects := True;
end;

procedure SchMcpResolveIncludes(const Tokens: TStringList; var F: TSchMcpInclude; var LegacyCombined: Boolean);
var
    i: Integer;
    T: String;
    AnyValid: Boolean;
begin
    LegacyCombined := (Tokens.Count = 0);
    if LegacyCombined then
        Exit;
    FillChar(F, SizeOf(F), 0);
    AnyValid := False;
    for i := 0 to Tokens.Count - 1 do
    begin
        T := Trim(LowerCase(Tokens[i]));
        if T = 'all' then
        begin
            SchMcpSetAllIncludes(F);
            AnyValid := True;
            Exit;
        end
        else if T = 'sheet' then begin F.WantSheet := True; AnyValid := True; end
        else if T = 'components' then begin F.WantComponents := True; AnyValid := True; end
        else if T = 'wires' then begin F.WantWires := True; AnyValid := True; end
        else if T = 'buses' then begin F.WantBuses := True; AnyValid := True; end
        else if T = 'net_labels' then begin F.WantNetLabels := True; AnyValid := True; end
        else if T = 'power_ports' then begin F.WantPowerPorts := True; AnyValid := True; end
        else if T = 'text_labels' then begin F.WantTextLabels := True; AnyValid := True; end
        else if T = 'junctions' then begin F.WantJunctions := True; AnyValid := True; end
        else if T = 'ports' then begin F.WantPorts := True; AnyValid := True; end
        else if T = 'off_sheet_connectors' then begin F.WantOffSheetConnectors := True; AnyValid := True; end
        else if T = 'sheet_symbols' then begin F.WantSheetSymbols := True; AnyValid := True; end
        else if T = 'directives' then begin F.WantDirectives := True; AnyValid := True; end
        else if T = 'figures' then begin F.WantFigures := True; AnyValid := True; end
        else if T = 'harness' then begin F.WantHarness := True; AnyValid := True; end
        else if T = 'drawing_objects' then begin F.WantDrawingObjects := True; AnyValid := True; end;
    end;
    if not AnyValid then
        LegacyCombined := True;
end;

procedure SchAppendFilteredDrawings(CurrentSch: ISch_Document; const Sheet: String;
    Target: TStringList; FilterKind: Integer);
var
    It: ISch_Iterator;
    Prim: ISch_BasicContainer;
begin
    It := CurrentSch.SchIterator_Create;
    case FilterKind of
        SCH_DRAW_FILTER_WIRES:
            It.AddFilter_ObjectSet(MkSet(eWire));
        SCH_DRAW_FILTER_BUSES:
            It.AddFilter_ObjectSet(MkSet(eBus, eBusEntry));
        SCH_DRAW_FILTER_NETLABELS:
            It.AddFilter_ObjectSet(MkSet(eNetLabel));
        SCH_DRAW_FILTER_POWER:
            It.AddFilter_ObjectSet(MkSet(ePowerObject));
        SCH_DRAW_FILTER_TEXT:
            It.AddFilter_ObjectSet(MkSet(eLabel));
        SCH_DRAW_FILTER_JUNCTIONS:
            It.AddFilter_ObjectSet(MkSet(eJunction));
        SCH_DRAW_FILTER_PORTS:
            It.AddFilter_ObjectSet(MkSet(ePort));
        SCH_DRAW_FILTER_OFFSHEET:
            It.AddFilter_ObjectSet(MkSet(eCrossSheetConnector));
        SCH_DRAW_FILTER_SHEETSYM:
            It.AddFilter_ObjectSet(MkSet(eSheetSymbol));
        SCH_DRAW_FILTER_DIRECTIVES:
            It.AddFilter_ObjectSet(MkSet(eNoERC, eCompileMask));
        SCH_DRAW_FILTER_FIGURES:
            It.AddFilter_ObjectSet(MkSet(eLine, ePolyline, eBezier, ePolygon, eRectangle, eEllipse, eArc, eRoundRectangle, eImage, eTextFrame, eConnectionLine));
    else
        begin
            CurrentSch.SchIterator_Destroy(It);
            Exit;
        end;
    end;
    Prim := It.FirstSchObject;
    while Prim <> nil do
    begin
        SchSerializeDrawingObject(Sheet, Prim, Target);
        Prim := It.NextSchObject;
    end;
    CurrentSch.SchIterator_Destroy(It);
end;

function SchBuildSheetInfoObject(CurrentSch: ISch_Document; const SheetPath: String): String;
var
    SheetProps: TStringList;
begin
    SheetProps := TStringList.Create;
    try
        AddJSONProperty(SheetProps, 'schematic_full_path', SheetPath, True);
        AddJSONBoolean(SheetProps, 'use_custom_sheet', CurrentSch.UseCustomSheet);
        AddJSONNumber(SheetProps, 'sheet_size_x_mils', CoordToMils(CurrentSch.GetState_SheetSizeX));
        AddJSONNumber(SheetProps, 'sheet_size_y_mils', CoordToMils(CurrentSch.GetState_SheetSizeY));
        AddJSONNumber(SheetProps, 'custom_x_mils', CoordToMils(CurrentSch.GetState_CustomX));
        AddJSONNumber(SheetProps, 'custom_y_mils', CoordToMils(CurrentSch.GetState_CustomY));
        AddJSONInteger(SheetProps, 'sheet_style_ordinal', Ord(CurrentSch.GetState_SheetStyle));
        AddJSONNumber(SheetProps, 'snap_grid_mils', CoordToMils(CurrentSch.GetState_SnapGridSize));
        AddJSONNumber(SheetProps, 'visible_grid_mils', CoordToMils(CurrentSch.GetState_VisibleGridSize));
        AddJSONBoolean(SheetProps, 'snap_grid_on', CurrentSch.SnapGridOn);
        AddJSONBoolean(SheetProps, 'visible_grid_on', CurrentSch.VisibleGridOn);
        AddJSONBoolean(SheetProps, 'title_block_on', CurrentSch.TitleBlockOn);
        AddJSONBoolean(SheetProps, 'border_on', CurrentSch.BorderOn);
        AddJSONProperty(SheetProps, 'template_file_name', CurrentSch.GetState_TemplateFileName, True);
        Result := BuildJSONObject(SheetProps);
    finally
        SheetProps.Free;
    end;
end;

// Match API paths from JSON (forward slashes, escaped backslashes) to Altium DM_FullPath (Windows)
function SchPathsEqual(const PathA, PathB: String): Boolean;
var
    NA, NB: String;
begin
    NA := Trim(LowerCase(McpNormalizeWindowsPath(PathA)));
    NB := Trim(LowerCase(McpNormalizeWindowsPath(PathB)));
    Result := AnsiCompareText(NA, NB) = 0;
end;

procedure SchAddGraphicalBboxMils(Gr: ISch_GraphicalObject; Props: TStringList);
var
    R: TCoordRect;
begin
    R := Gr.BoundingRectangle;
    AddJSONNumber(Props, 'bbox_left_mils', CoordToMils(R.Left));
    AddJSONNumber(Props, 'bbox_right_mils', CoordToMils(R.Right));
    AddJSONNumber(Props, 'bbox_top_mils', CoordToMils(R.Top));
    AddJSONNumber(Props, 'bbox_bottom_mils', CoordToMils(R.Bottom));
end;

procedure SchAppendVerticesMilsJson(Props: TStringList; Poly: ISch_Polygon);
var
    VItems, Pair: TStringList;
    VC, i: Integer;
    Pt: TLocation;
begin
    VItems := TStringList.Create;
    try
        VC := Poly.VerticesCount;
        for i := 1 to VC do
        begin
            Pt := Poly.GetState_Vertex(i);
            Pair := TStringList.Create;
            try
                AddJSONNumber(Pair, 'x_mils', CoordToMils(Pt.X));
                AddJSONNumber(Pair, 'y_mils', CoordToMils(Pt.Y));
                VItems.Add(BuildJSONObject(Pair, 1));
            finally
                Pair.Free;
            end;
        end;
        if VItems.Count > 0 then
            Props.Add('"vertices_mils": ' + BuildJSONArray(VItems, '', 0));
    finally
        VItems.Free;
    end;
end;

function SchSchematicDrawingObjectKind(ObjId: TObjectId): String;
begin
    if ObjId = eWire then Result := 'eWire'
    else if ObjId = eBus then Result := 'eBus'
    else if ObjId = eBusEntry then Result := 'eBusEntry'
    else if ObjId = eNetLabel then Result := 'eNetLabel'
    else if ObjId = eLabel then Result := 'eLabel'
    else if ObjId = eLine then Result := 'eLine'
    else if ObjId = eJunction then Result := 'eJunction'
    else if ObjId = ePort then Result := 'ePort'
    else if ObjId = ePowerObject then Result := 'ePowerObject'
    else if ObjId = eCrossSheetConnector then Result := 'eCrossSheetConnector'
    else if ObjId = eSheetSymbol then Result := 'eSheetSymbol'
    else if ObjId = eNoERC then Result := 'eNoERC'
    else if ObjId = eConnectionLine then Result := 'eConnectionLine'
    else if ObjId = ePolyline then Result := 'ePolyline'
    else if ObjId = eBezier then Result := 'eBezier'
    else if ObjId = ePolygon then Result := 'ePolygon'
    else if ObjId = eRectangle then Result := 'eRectangle'
    else if ObjId = eEllipse then Result := 'eEllipse'
    else if ObjId = eArc then Result := 'eArc'
    else if ObjId = eRoundRectangle then Result := 'eRoundRectangle'
    else if ObjId = eImage then Result := 'eImage'
    else if ObjId = eTextFrame then Result := 'eTextFrame'
    else if ObjId = eCompileMask then Result := 'eCompileMask'
    else Result := 'unknown';
end;

// Non-component primitives on the sheet (wires, buses, graphics, labels, etc.).
// Sheet title-block / document parameters (eParameter) are omitted — noise for MCP; component parameters stay under components[].
procedure SchSerializeDrawingObject(const Sheet: String; Obj: ISch_BasicContainer; Drawings: TStringList);
var
    Props: TStringList;
    Gr: ISch_GraphicalObject;
    Poly: ISch_Polygon;
    Ln: ISch_Line;
    NL: ISch_NetLabel;
    Lb: ISch_Label;
    Pr: ISch_Port;
    SSym: ISch_SheetSymbol;
    Jun: ISch_Junction;
begin
    Props := TStringList.Create;
    try
        AddJSONProperty(Props, 'sheet', Sheet);
        AddJSONProperty(Props, 'object_kind', SchSchematicDrawingObjectKind(Obj.ObjectId));
        AddJSONInteger(Props, 'object_id', Ord(Obj.ObjectId));

        Gr := Obj;
        SchAddGraphicalBboxMils(Gr, Props);

        if (Obj.ObjectId = eWire) or (Obj.ObjectId = eBus) or
           (Obj.ObjectId = ePolyline) or (Obj.ObjectId = eBezier) or (Obj.ObjectId = ePolygon) then
        begin
            Poly := Obj;
            SchAppendVerticesMilsJson(Props, Poly);
        end
        else if (Obj.ObjectId = eBusEntry) or (Obj.ObjectId = eLine) or (Obj.ObjectId = eConnectionLine) then
        begin
            Ln := Obj;
            AddJSONNumber(Props, 'x1_mils', CoordToMils(Ln.Location.X));
            AddJSONNumber(Props, 'y1_mils', CoordToMils(Ln.Location.Y));
            AddJSONNumber(Props, 'x2_mils', CoordToMils(Ln.Corner.X));
            AddJSONNumber(Props, 'y2_mils', CoordToMils(Ln.Corner.Y));
        end
        else if Obj.ObjectId = eNetLabel then
        begin
            NL := Obj;
            AddJSONProperty(Props, 'text', NL.Text);
            AddJSONNumber(Props, 'x_mils', CoordToMils(NL.Location.X));
            AddJSONNumber(Props, 'y_mils', CoordToMils(NL.Location.Y));
        end
        else if (Obj.ObjectId = eLabel) or (Obj.ObjectId = ePowerObject) or (Obj.ObjectId = eCrossSheetConnector) then
        begin
            Lb := Obj;
            AddJSONProperty(Props, 'text', Lb.Text);
            AddJSONNumber(Props, 'x_mils', CoordToMils(Lb.Location.X));
            AddJSONNumber(Props, 'y_mils', CoordToMils(Lb.Location.Y));
        end
        else if Obj.ObjectId = eJunction then
        begin
            Jun := Obj;
            AddJSONNumber(Props, 'x_mils', CoordToMils(Jun.Location.X));
            AddJSONNumber(Props, 'y_mils', CoordToMils(Jun.Location.Y));
        end
        else if Obj.ObjectId = ePort then
        begin
            Pr := Obj;
            AddJSONProperty(Props, 'name', Pr.Name);
            AddJSONNumber(Props, 'x_mils', CoordToMils(Pr.Location.X));
            AddJSONNumber(Props, 'y_mils', CoordToMils(Pr.Location.Y));
        end
        else if Obj.ObjectId = eSheetSymbol then
        begin
            SSym := Obj;
            AddJSONProperty(Props, 'sheet_file_name', SSym.SheetFileName);
            AddJSONProperty(Props, 'sheet_name', SSym.SheetName);
        end;

        Drawings.Add(BuildJSONObject(Props, 1));
    finally
        Props.Free;
    end;
end;

procedure SchCollectDrawingObjectsForSheet(CurrentSch: ISch_Document; const Sheet: String; Drawings: TStringList);
var
    It: ISch_Iterator;
    Prim: ISch_BasicContainer;
begin
    It := CurrentSch.SchIterator_Create;
    It.AddFilter_ObjectSet(MkSet(
        eWire, eBus, eBusEntry, eNetLabel, eLabel, eLine, eJunction, ePort, ePowerObject,
        eCrossSheetConnector, eSheetSymbol, eNoERC, eConnectionLine,
        ePolyline, eBezier, ePolygon, eRectangle, eEllipse, eArc, eRoundRectangle,
        eImage, eTextFrame, eCompileMask));
    Prim := It.FirstSchObject;
    while Prim <> nil do
    begin
        SchSerializeDrawingObject(Sheet, Prim, Drawings);
        Prim := It.NextSchObject;
    end;
    CurrentSch.SchIterator_Destroy(It);
end;

// project_full_path / schematic_full_path / sheet file name: all optional (empty = focused project, all sheets).
// RequestData: optional include_queries JSON array; when absent, legacy shape { components, drawing_objects } only.
function GetSchematicData(ROOT_DIR: String; ProjectFullPath, SchematicFullPath, SheetFileFilter: String;
    RequestData: TStringList): String;
var
    WS          : IWorkspace;
    Project     : IProject;
    Doc         : IDocument;
    CurrentSch  : ISch_Document;
    Iterator    : ISch_Iterator;
    PIterator   : ISch_Iterator;
    Component   : ISch_Component;
    Parameter, NextParameter : ISch_Parameter;
    Rect        : TCoordRect;
    ComponentsArray : TStringList;
    DrawingsArray   : TStringList;
    RootPairs       : TStringList;
    CompProps   : TStringList;
    ParamsProps : TStringList;
    OutputLines : TStringList;
    Designator, Sheet, ParameterName, ParameterValue : String;
    x, y, width, height, rotation : String;
    left, right, top, bottom : String;
    i, pi       : Integer;
    SchematicCount, ComponentCount : Integer;
    Found       : Boolean;
    IncludeTokens   : TStringList;
    IncFlags        : TSchMcpInclude;
    LegacyCombined  : Boolean;
    SheetsJsonParts : TStringList;
    WiresSL, BusesSL, NetLabelsSL, PowerSL, TextSL, JunSL, PortsSL, OffSL, SheetSymSL, DirSL, FigSL : TStringList;
    EchoSL          : TStringList;
begin
    Result := '';

    WS := GetWorkspace;
    if WS = nil then
    begin
        Result := 'ERROR: NO_WORKSPACE';
        Exit;
    end;

    Project := nil;

    if ProjectFullPath <> '' then
        ProjectFullPath := McpNormalizeWindowsPath(ProjectFullPath);
    if SchematicFullPath <> '' then
        SchematicFullPath := McpNormalizeWindowsPath(SchematicFullPath);

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
                if SchPathsEqual(Doc.DM_FullPath, SchematicFullPath) then
                begin
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
            if (WS.DM_Projects(pi) <> nil) and SchPathsEqual(WS.DM_Projects(pi).DM_ProjectFullPath, ProjectFullPath) then
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
    end
    else
        Project := WS.DM_FocusedProject;

    if Project = nil then
    begin
        Result := 'ERROR: NO_FOCUSED_PROJECT';
        Exit;
    end;

    IncludeTokens := TStringList.Create;
    try
        if RequestData <> nil then
            SchDataParseStringArray(RequestData, '"include_queries"', IncludeTokens);
        SchMcpResolveIncludes(IncludeTokens, IncFlags, LegacyCombined);

    // Create array for components and non-component drawing primitives
    ComponentsArray := TStringList.Create;
    DrawingsArray := TStringList.Create;
    SheetsJsonParts := nil;
    WiresSL := nil;
    BusesSL := nil;
    NetLabelsSL := nil;
    PowerSL := nil;
    TextSL := nil;
    JunSL := nil;
    PortsSL := nil;
    OffSL := nil;
    SheetSymSL := nil;
    DirSL := nil;
    FigSL := nil;
    if not LegacyCombined then
    begin
        SheetsJsonParts := TStringList.Create;
        WiresSL := TStringList.Create;
        BusesSL := TStringList.Create;
        NetLabelsSL := TStringList.Create;
        PowerSL := TStringList.Create;
        TextSL := TStringList.Create;
        JunSL := TStringList.Create;
        PortsSL := TStringList.Create;
        OffSL := TStringList.Create;
        SheetSymSL := TStringList.Create;
        DirSL := TStringList.Create;
        FigSL := TStringList.Create;
    end;

    try
        // Count the number of schematic documents
        SchematicCount := 0;
        For i := 0 to Project.DM_LogicalDocumentCount - 1 Do
        Begin
            Doc := Project.DM_LogicalDocuments(i);
            If Doc.DM_DocumentKind = 'SCH' Then
                SchematicCount := SchematicCount + 1;
        End;

        // Process each schematic document
        ComponentCount := 0;
        For i := 0 to Project.DM_LogicalDocumentCount - 1 Do
        Begin
            Doc := Project.DM_LogicalDocuments(i);
            If Doc.DM_DocumentKind = 'SCH' Then
            Begin
                if SchematicFullPath <> '' then
                begin
                    if not SchPathsEqual(Doc.DM_FullPath, SchematicFullPath) then
                        Continue;
                end
                else if SheetFileFilter <> '' then
                begin
                    if AnsiCompareText(LowerCase(ExtractFileName(Doc.DM_FullPath)), LowerCase(SheetFileFilter)) <> 0 then
                        Continue;
                end;

                // Open the schematic document
                Client.OpenDocument('SCH', Doc.DM_FullPath);
                CurrentSch := SchServer.GetSchDocumentByPath(Doc.DM_FullPath);

                If (CurrentSch <> Nil) Then
                Begin
                    if LegacyCombined or IncFlags.WantComponents then
                    begin
                    // Get schematic components
                    Iterator := CurrentSch.SchIterator_Create;
                    Iterator.AddFilter_ObjectSet(MkSet(eSchComponent));

                    Component := Iterator.FirstSchObject;
                    While (Component <> Nil) Do
                    Begin
                        // Create component properties
                        CompProps := TStringList.Create;
                        
                        try
                            // Get basic component properties
                            Designator := Component.Designator.Text;
                            Sheet := Doc.DM_FullPath;

                            // Get position, dimensions and rotation
                            x := FloatToStr(CoordToMils(Component.Location.X));
                            y := FloatToStr(CoordToMils(Component.Location.Y));

                            Rect := Component.BoundingRectangle;
                            left := FloatToStr(CoordToMils(Rect.Left));
                            right := FloatToStr(CoordToMils(Rect.Right));
                            top := FloatToStr(CoordToMils(Rect.Top));
                            bottom := FloatToStr(CoordToMils(Rect.Bottom));

                            width := FloatToStr(CoordToMils(Rect.Right - Rect.Left));
                            height := FloatToStr(CoordToMils(Rect.Bottom - Rect.Top));

                            If Component.Orientation = eRotate0 Then
                                rotation := '0'
                            Else If Component.Orientation = eRotate90 Then
                                rotation := '90'
                            Else If Component.Orientation = eRotate180 Then
                                rotation := '180'
                            Else If Component.Orientation = eRotate270 Then
                                rotation := '270'
                            Else
                                rotation := '0';

                            // Add component properties
                            AddJSONProperty(CompProps, 'designator', Designator);
                            AddJSONProperty(CompProps, 'sheet', Sheet);
                            AddJSONNumber(CompProps, 'schematic_x', StrToFloat(x));
                            AddJSONNumber(CompProps, 'schematic_y', StrToFloat(y));
                            AddJSONNumber(CompProps, 'schematic_width', StrToFloat(width));
                            AddJSONNumber(CompProps, 'schematic_height', StrToFloat(height));
                            AddJSONNumber(CompProps, 'schematic_rotation', StrToFloat(rotation));
                            
                            // Get parameters
                            ParamsProps := TStringList.Create;
                            try
                                // Create parameter iterator
                                PIterator := Component.SchIterator_Create;
                                PIterator.AddFilter_ObjectSet(MkSet(eParameter));

                                Parameter := PIterator.FirstSchObject;
                                
                                // Process all parameters
                                while (Parameter <> nil) do
                                begin
                                    // Get this parameter's info
                                    ParameterName := Parameter.Name;
                                    ParameterValue := Parameter.Text;

                                    // Add parameter to the list
                                    AddJSONProperty(ParamsProps, ParameterName, ParameterValue);
                                    
                                    // Move to next parameter
                                    Parameter := PIterator.NextSchObject;
                                end;

                                Component.SchIterator_Destroy(PIterator);
                                
                                // Add parameters to component
                                CompProps.Add('"parameters": ' + BuildJSONObject(ParamsProps, 2));
                                
                                // Add to components array
                                ComponentsArray.Add(BuildJSONObject(CompProps, 1));
                                ComponentCount := ComponentCount + 1;
                            finally
                                ParamsProps.Free;
                            end;
                        finally
                            CompProps.Free;
                        end;

                        // Move to next component
                        Component := Iterator.NextSchObject;
                    End;

                    CurrentSch.SchIterator_Destroy(Iterator);
                    end;

                    if LegacyCombined then
                        SchCollectDrawingObjectsForSheet(CurrentSch, Doc.DM_FullPath, DrawingsArray)
                    else begin
                        if IncFlags.WantSheet and (SheetsJsonParts <> nil) then
                            SheetsJsonParts.Add(SchBuildSheetInfoObject(CurrentSch, Doc.DM_FullPath));
                        if IncFlags.WantWires then
                            SchAppendFilteredDrawings(CurrentSch, Doc.DM_FullPath, WiresSL, SCH_DRAW_FILTER_WIRES);
                        if IncFlags.WantBuses then
                            SchAppendFilteredDrawings(CurrentSch, Doc.DM_FullPath, BusesSL, SCH_DRAW_FILTER_BUSES);
                        if IncFlags.WantNetLabels then
                            SchAppendFilteredDrawings(CurrentSch, Doc.DM_FullPath, NetLabelsSL, SCH_DRAW_FILTER_NETLABELS);
                        if IncFlags.WantPowerPorts then
                            SchAppendFilteredDrawings(CurrentSch, Doc.DM_FullPath, PowerSL, SCH_DRAW_FILTER_POWER);
                        if IncFlags.WantTextLabels then
                            SchAppendFilteredDrawings(CurrentSch, Doc.DM_FullPath, TextSL, SCH_DRAW_FILTER_TEXT);
                        if IncFlags.WantJunctions then
                            SchAppendFilteredDrawings(CurrentSch, Doc.DM_FullPath, JunSL, SCH_DRAW_FILTER_JUNCTIONS);
                        if IncFlags.WantPorts then
                            SchAppendFilteredDrawings(CurrentSch, Doc.DM_FullPath, PortsSL, SCH_DRAW_FILTER_PORTS);
                        if IncFlags.WantOffSheetConnectors then
                            SchAppendFilteredDrawings(CurrentSch, Doc.DM_FullPath, OffSL, SCH_DRAW_FILTER_OFFSHEET);
                        if IncFlags.WantSheetSymbols then
                            SchAppendFilteredDrawings(CurrentSch, Doc.DM_FullPath, SheetSymSL, SCH_DRAW_FILTER_SHEETSYM);
                        if IncFlags.WantDirectives then
                            SchAppendFilteredDrawings(CurrentSch, Doc.DM_FullPath, DirSL, SCH_DRAW_FILTER_DIRECTIVES);
                        if IncFlags.WantFigures then
                            SchAppendFilteredDrawings(CurrentSch, Doc.DM_FullPath, FigSL, SCH_DRAW_FILTER_FIGURES);
                        if IncFlags.WantDrawingObjects then
                            SchCollectDrawingObjectsForSheet(CurrentSch, Doc.DM_FullPath, DrawingsArray);
                    end;
                End;
            End;
        End;

        // Root JSON: legacy { components, drawing_objects } or filtered buckets + include_queries echo
        OutputLines := TStringList.Create;
        RootPairs := TStringList.Create;
        EchoSL := TStringList.Create;
        try
            if LegacyCombined then
            begin
                RootPairs.Add(JSONPairStr('components', BuildJSONArray(ComponentsArray), False));
                RootPairs.Add(JSONPairStr('drawing_objects', BuildJSONArray(DrawingsArray), False));
            end
            else begin
                RootPairs.Add(JSONPairStr('schematic_data_mode', 'filtered', True));
                for i := 0 to IncludeTokens.Count - 1 do
                    EchoSL.Add('"' + JSONEscapeString(IncludeTokens[i]) + '"');
                RootPairs.Add(JSONPairStr('include_queries', BuildJSONArray(EchoSL, '', 0), False));
                if IncFlags.WantSheet and (SheetsJsonParts <> nil) then
                    RootPairs.Add(JSONPairStr('sheets', BuildJSONArray(SheetsJsonParts, '', 0), False));
                if IncFlags.WantComponents then
                    RootPairs.Add(JSONPairStr('components', BuildJSONArray(ComponentsArray), False));
                if IncFlags.WantWires then
                    RootPairs.Add(JSONPairStr('wires', BuildJSONArray(WiresSL), False));
                if IncFlags.WantBuses then
                    RootPairs.Add(JSONPairStr('buses', BuildJSONArray(BusesSL), False));
                if IncFlags.WantNetLabels then
                    RootPairs.Add(JSONPairStr('net_labels', BuildJSONArray(NetLabelsSL), False));
                if IncFlags.WantPowerPorts then
                    RootPairs.Add(JSONPairStr('power_ports', BuildJSONArray(PowerSL), False));
                if IncFlags.WantTextLabels then
                    RootPairs.Add(JSONPairStr('text_labels', BuildJSONArray(TextSL), False));
                if IncFlags.WantJunctions then
                    RootPairs.Add(JSONPairStr('junctions', BuildJSONArray(JunSL), False));
                if IncFlags.WantPorts then
                    RootPairs.Add(JSONPairStr('ports', BuildJSONArray(PortsSL), False));
                if IncFlags.WantOffSheetConnectors then
                    RootPairs.Add(JSONPairStr('off_sheet_connectors', BuildJSONArray(OffSL), False));
                if IncFlags.WantSheetSymbols then
                    RootPairs.Add(JSONPairStr('sheet_symbols', BuildJSONArray(SheetSymSL), False));
                if IncFlags.WantDirectives then
                    RootPairs.Add(JSONPairStr('directives', BuildJSONArray(DirSL), False));
                if IncFlags.WantFigures then
                    RootPairs.Add(JSONPairStr('figures', BuildJSONArray(FigSL), False));
                if IncFlags.WantDrawingObjects then
                    RootPairs.Add(JSONPairStr('drawing_objects', BuildJSONArray(DrawingsArray), False));
                if IncFlags.WantHarness then
                    RootPairs.Add('"harness": []');
            end;
            OutputLines.Text := BuildJSONObject(RootPairs);
            Result := WriteJSONToFile(OutputLines, ROOT_DIR+'temp_schematic_data.json');
        finally
            EchoSL.Free;
            RootPairs.Free;
            OutputLines.Free;
        end;
    finally
        if FigSL <> nil then FigSL.Free;
        if DirSL <> nil then DirSL.Free;
        if SheetSymSL <> nil then SheetSymSL.Free;
        if OffSL <> nil then OffSL.Free;
        if PortsSL <> nil then PortsSL.Free;
        if JunSL <> nil then JunSL.Free;
        if TextSL <> nil then TextSL.Free;
        if PowerSL <> nil then PowerSL.Free;
        if NetLabelsSL <> nil then NetLabelsSL.Free;
        if BusesSL <> nil then BusesSL.Free;
        if WiresSL <> nil then WiresSL.Free;
        if SheetsJsonParts <> nil then SheetsJsonParts.Free;
        DrawingsArray.Free;
        ComponentsArray.Free;
    end;
    finally
        IncludeTokens.Free;
    end;
end;
