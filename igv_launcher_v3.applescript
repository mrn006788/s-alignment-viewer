-- AlignmentViewer.app  (v3 — generic, no hardcoded paths)
-- Double-click : select BAM via file picker → setup → open browser
-- Drop BAM (+ optional FASTA) : run setup then open browser
-- FASTA is optional: reference is auto-generated from BAM if not provided

property serverPort : "8765"

-- ── Helpers ────────────────────────────────────────────────────────

-- Path to the app bundle itself
on appBundlePath()
    return POSIX path of (path to me)
end appBundlePath

-- Directory containing our bundled scripts
on scriptsDirPath()
    return appBundlePath() & "Contents/Resources/scripts/"
end scriptsDirPath

-- igv.html template bundled inside the app
on igvTemplatePath()
    return appBundlePath() & "Contents/Resources/igv.html"
end igvTemplatePath

-- Last workspace saved by setup_viewer.sh
on lastWorkspace()
    try
        return do shell script "cat ~/.alignmentviewer_workspace 2>/dev/null || true"
    on error
        return ""
    end try
end lastWorkspace

-- Kill any existing server on the port then start a new one
on startServer(workDir)
    set sd to scriptsDirPath()
    try
        do shell script "lsof -ti tcp:" & serverPort & " | xargs kill -9 2>/dev/null; true"
    end try
    delay 0.5
    do shell script "/usr/bin/python3 " & quoted form of (sd & "range_server.py") & " " & quoted form of workDir & " > /tmp/igv_server.log 2>&1 &"
    delay 2
    open location "http://localhost:" & serverPort & "/igv.html"
    display notification "http://localhost:" & serverPort & "/igv.html" with title "Alignment Viewer" subtitle "Workspace: " & workDir
end startServer

-- ── Double-click ───────────────────────────────────────────────────
on run
    -- Step 1: Select BAM file
    try
        set bamAlias to choose file with prompt "Select a BAM file:" of type {"com.public.data", "public.data"} without invisibles
    on error number -128
        return -- user cancelled
    end try
    set bamFile to POSIX path of bamAlias

    -- Workspace = directory containing BAM
    set workDir to do shell script "dirname " & quoted form of bamFile

    -- Check BAI index
    set baiPath to bamFile & ".bai"
    set baiExists to do shell script "test -f " & quoted form of baiPath & " && echo yes || echo no"
    if baiExists is "no" then
        set choice to button returned of (display alert "Index file missing" message (bamFile & ".bai not found.") & return & "Create it now with samtools?" buttons {"Cancel", "Create"} default button "Create")
        if choice is "Cancel" then return
        set samtoolsPath to do shell script "command -v samtools 2>/dev/null || echo /opt/homebrew/bin/samtools"
        do shell script quoted form of samtoolsPath & " index " & quoted form of bamFile
    end if

    -- Check if setup was already done (reads_ref60.fa exists)
    set hasRef to do shell script "test -f " & quoted form of (workDir & "/reads_ref60.fa") & " && echo yes || echo no"
    if hasRef is "yes" then
        set choice to button returned of (display alert "Open viewer" message "Setup already done for:" & return & workDir & return & return & "Open the viewer?" buttons {"Re-run setup", "Open"} default button "Open")
        if choice is "Open" then
            startServer(workDir)
            return
        end if
    end if

    -- Run setup (no FASTA needed — auto-generated from BAM)
    runSetup(bamFile, "", workDir)
end run

-- ── Drag & drop ────────────────────────────────────────────────────
on open droppedFiles
    set bamFile to ""
    set refFile to ""

    repeat with aFile in droppedFiles
        set fp to POSIX path of aFile
        if fp ends with "/" then set fp to text 1 thru -2 of fp
        if fp ends with ".bam" then
            set bamFile to fp
        else if fp ends with ".fa" or fp ends with ".fasta" or fp ends with ".fna" then
            set refFile to fp
        end if
    end repeat

    if bamFile is "" then
        display alert "No BAM file" message "Please drop a .bam file (and optionally a .fa reference) onto this app."
        return
    end if

    -- Workspace = directory containing the BAM
    set workDir to do shell script "dirname " & quoted form of bamFile

    -- Check BAI index
    set baiPath to bamFile & ".bai"
    set baiExists to do shell script "test -f " & quoted form of baiPath & " && echo yes || echo no"
    if baiExists is "no" then
        set choice to button returned of (display alert "Index file missing" message (bamFile & ".bai not found.") & return & "Create it now with samtools?" buttons {"Cancel", "Create"} default button "Create")
        if choice is "Cancel" then return
        set samtoolsPath to do shell script "command -v samtools 2>/dev/null || echo /opt/homebrew/bin/samtools"
        do shell script quoted form of samtoolsPath & " index " & quoted form of bamFile
    end if

    -- FASTA is optional: if not dropped, auto-generate from BAM
    if refFile is "" then
        set hasRef to do shell script "test -f " & quoted form of (workDir & "/reads_ref60.fa") & " && echo yes || echo no"
        if hasRef is "yes" then
            set choice to button returned of (display alert "Open viewer" message "Setup already done for:" & return & workDir & return & return & "Open the viewer?" buttons {"Re-run setup", "Open"} default button "Open")
            if choice is "Open" then
                startServer(workDir)
                return
            end if
        end if
    end if

    -- Run setup (FASTA may be empty — consensus generated automatically)
    runSetup(bamFile, refFile, workDir)
end open

-- ── Setup ──────────────────────────────────────────────────────────
on runSetup(bamPath, refPath, workDir)
    set sd to scriptsDirPath()
    set tmpl to igvTemplatePath()

    -- Build command (workspace passed via env var to avoid positional ambiguity)
    set envVars to "SCRIPTS_DIR=" & quoted form of sd & " IGV_TEMPLATE=" & quoted form of tmpl & " VIEWER_WORKSPACE=" & quoted form of workDir
    if refPath is "" then
        set setupCmd to envVars & " bash " & quoted form of (sd & "setup_viewer.sh") & " " & quoted form of bamPath
    else
        set setupCmd to envVars & " bash " & quoted form of (sd & "setup_viewer.sh") & " " & quoted form of bamPath & " " & quoted form of refPath
    end if

    tell application "Terminal"
        activate
        do script setupCmd
    end tell

    -- Wait for setup to finish (reads_ref60.fa.fai as signal, up to 10 min)
    set isDone to "no"
    repeat 300 times
        delay 2
        set isDone to do shell script "test -f " & quoted form of (workDir & "/reads_ref60.fa.fai") & " && echo yes || echo no"
        if isDone is "yes" then exit repeat
    end repeat

    if isDone is "no" then
        display alert "Setup timeout" message "Setup did not finish in 10 minutes. Check the Terminal for errors."
        return
    end if

    delay 1
    startServer(workDir)
end runSetup
