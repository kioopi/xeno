# Editor integration

Xeno should be able to use the File System API of the browser to create a
local copy of the Notes in the user's file system.
Since Notes reference a Directory in Xeno, we can create the correct
directory structure.

The whole directory tree then gets watched for changes, and when a Note
is saved in the file system, Xeno picks up the change and updates the
Note in the database.

Changes in the database should also get pushed down to the file system
but that is a later iteration.

This way users can use their favorite editor to edit Notes.

<https://developer.mozilla.org/en-US/docs/Web/API/File_System_API>
<https://developer.chrome.com/docs/capabilities/web-apis/file-system-access>

Scott Tolinski of the syntax.fm podcast built a similar feature
for a live CSS Battle game but the source code does not seem to be available
right now.

<https://syntax.fm/show/934/we-built-a-real-time-local-data-competitive-coding-game>
<https://www.youtube.com/watch?v=_tHSAKVCJQo>

---

Das ist ein spannendes und anspruchsvolles Feature, das Sie mit Ihrem Stack aus Elixir, Ash, Phoenix und LiveView in Kombination mit der File System Access API (FSA API) des Browsers umsetzen möchten. Ash ist ein hervorragendes Framework, um die Domänenlogik (wie die Verzeichnisstruktur für Notizen) zu modellieren, während Phoenix LiveView die reaktive Benutzeroberfläche und die Echtzeitkommunikation mit dem Browser bereitstellt.

Hier ist ein Überblick über die notwendigen Schritte und potenziellen Herausforderungen, die Sie bei der Implementierung dieser Funktion berücksichtigen müssen, basierend auf den bereitgestellten Quellen:

---

### I. Notwendige Überlegungen und Schritte im Frontend (Browser/JavaScript)

Die gesamte Interaktion mit dem lokalen Dateisystem wird über die **FSA API** (File System Access API) im Browser-JavaScript abgewickelt. ,

#### 1. Sicherheit und Benutzerzugriff (Voraussetzungen)
*   **Sicherer Kontext:** Die FSA API ist nur in **sicheren Kontexten (HTTPS)** verfügbar.
*   **Benutzergeste:** Der Zugriff auf das lokale Dateisystem, insbesondere das Öffnen eines Verzeichnisauswahlfensters (`showDirectoryPicker`), muss durch eine **Benutzergeste** (wie einen Klick auf eine Schaltfläche) ausgelöst werden.
*   **Verzeichnis-Handle abrufen:** Sie müssen `Window.showDirectoryPicker()` verwenden, um den Benutzer aufzufordern, das Stammverzeichnis der Notizen auszuwählen. Dies gibt Ihnen ein `FileSystemDirectoryHandle` zurück, welches den Zugriff auf die Verzeichnisstruktur ermöglicht.
*   **Persistenz und Berechtigungen:** Die erteilten Berechtigungen sind nicht immer dauerhaft. Um den Zugriff über Sitzungen hinweg aufrechtzuerhalten, müssen Sie das `FileSystemDirectoryHandle`-Objekt in einer Datenbank speichern, die die Serialisierung unterstützt, typischerweise in **IndexedDB**. Bei der Wiederherstellung der Anwendung müssen Sie die Berechtigung mithilfe von `queryPermission()` überprüfen und gegebenenfalls mit `requestPermission()` **erneut anfordern**.

#### 2. Erstellen der lokalen Kopie
*   **Verzeichnisstruktur abbilden:** Da Ihre App eine Verzeichnisstruktur für Notizen verwendet, müssen Sie diese Struktur (die in Ihrer Ash-Datenbank gespeichert ist) lokal neu erstellen, indem Sie das `FileSystemDirectoryHandle` rekursiv durchlaufen.
*   **Verzeichnisse erstellen:** Verwenden Sie die Methode `getDirectoryHandle(name, {create: true})` für Ordner.
*   **Dateien erstellen/schreiben:** Um die Markdown- oder TXT-Dateien zu erstellen, verwenden Sie `getFileHandle(name, {create: true})`.
*   **Inhalte schreiben:** Zum Schreiben in die Datei müssen Sie einen beschreibbaren Stream erstellen (`fileHandle.createWritable()`). Der Schreibvorgang erfolgt asynchron über `writableStream.write(contents)` (wobei `contents` ein `Blob`, `String` oder `Buffer` sein kann). **Wichtig:** Sie müssen `await writableStream.close()` aufrufen, um die Datei zu schließen und die Inhalte tatsächlich auf die Festplatte zu schreiben.

#### 3. Änderungen im Dateisystem überwachen

Dies ist ein kritischer und potenziell herausfordernder Teil, da Sie Änderungen erkennen müssen, die von externen Editoren vorgenommen wurden.

*   **Der FileSystemObserver (Experimentell):** Die Schnittstelle `FileSystemObserver` bietet einen Mechanismus, um Änderungen an ausgewählten Dateien oder Verzeichnissen zu beobachten. Dies würde verhindern, dass Ihre Webanwendung das Dateisystem ständig abfragen muss.
    *   **Herausforderung:** Die `FileSystemObserver`-API ist derzeit als **experimentell** und **nicht standardisiert** gekennzeichnet. Es wird **nicht empfohlen**, nicht standardisierte Funktionen in der Produktion zu verwenden, da sie eine begrenzte Browserunterstützung haben und sich ändern oder entfernt werden können.
*   **Alternative: Polling:** Eine alternative Strategie, die in einem ähnlichen Projekt angewendet wurde, ist das **regelmäßige Polling** (z. B. 10 Mal pro Sekunde) der Dateien auf Änderungen. Bei Erkennung einer Änderung wird der aktuelle Inhalt in die Datenbank gespeichert.
*   **Implementierung (bei Änderung):** Wenn eine Änderung erkannt wird (entweder durch Observer oder Polling):
    1.  Die Anwendung muss den neuen Inhalt der geänderten Datei abrufen. Dies geschieht durch erneutes Aufrufen von `fileHandle.getFile()` und anschließendes Auslesen des Inhalts (z. B. `file.text()` für Textdateien).
    2.  Die gelesenen Inhalte müssen dann zur Datenbank-Aktualisierung an den Elixir/LiveView-Backend gesendet werden.

---

### II. Backend-Integration (Elixir/Phoenix/Ash)

Die Integration in Ihren Elixir/Ash/Phoenix/LiveView-Stack beinhaltet die effiziente Verarbeitung der vom Browser gesendeten Änderungen und deren Speicherung in der Datenbank.

#### 1. Kommunikation Browser $\rightarrow$ LiveView
*   **Ereignis-Handling:** Die asynchrone JavaScript-Logik, die die Dateiänderungen erkennt, muss ein Ereignis an die LiveView-Instanz senden. Dies geschieht typischerweise über LiveView-Ereignis-Handler (`handle_event/3`) oder durch das Senden von Nachrichten (`handle_info/2`), die durch clientseitige Hooks ausgelöst werden.
*   **Nutzlast:** Die gesendete Nachricht muss die identifizierende Information der Notiz (z. B. ID oder Pfad) sowie den **vollständigen, aktualisierten Inhalt** der Markdown/TXT-Datei als String enthalten.

#### 2. Datenverarbeitung und Speicherung (Ash)
*   **Domänenmodell:** Sie verwenden Ash, um Ihr Domänenmodell (die `Note` Ressource) zu beschreiben, einschließlich ihrer Attribute und der Verzeichnisstruktur.
*   **Aktionen und Changesets:** LiveView sendet die Nutzlast an Ihren Ash-Layer. Die Aktualisierung der Notiz in der Datenbank erfolgt über eine Ash-Update-Aktion (z. B. `:update`).
    *   Ash verwendet `Changesets` zur sicheren Validierung und Verarbeitung von Daten. Wenn Sie die Änderung (den neuen Inhalt) übergeben, wird ein Changeset erstellt und die hinterlegte Geschäftslogik (Validierungen, etc.) ausgeführt.
    *   Wenn Sie das gesamte `Note` Objekt als String speichern, wird dieser String in die Datenbank persistiert.

#### 3. Überlegungen zur Verzeichnisstruktur und Pfaden
*   **Pfad-Mapping:** Da die FSA API hauptsächlich mit Handles arbeitet und die direkte Verwendung traditioneller Pfade (`foo/bar/bleh.txt`) kompliziert sein kann, müssen Sie im JavaScript sicherstellen, dass Sie die **eindeutige ID** oder den **relativen Pfad** (den Sie mit `directoryHandle.resolve()` abrufen können) einer geänderten Datei bestimmen und an den Elixir-Backend übermitteln, damit die richtige `Note` in der Datenbank aktualisiert werden kann.

### III. Potenzielle Herausforderungen und Einschränkungen

Zusätzlich zu den oben genannten Punkten sollten Sie Folgendes beachten:

*   **Browser-Kompatibilität:** Derzeit wird die FSA API nicht von allen wichtigen Browsern unterstützt, insbesondere **Firefox und IE** bieten keine native Unterstützung (obwohl eine Polyfill-Bibliothek `browser-fs-access` existiert).
*   **Umgang mit Fehlern:** Die API kann verschiedene Ausnahmen werfen, die oft komplex sind und von der Interaktion mit dem zugrunde liegenden Betriebssystem abhängen. Ihre JavaScript-Logik muss robust sein, um diese Fehler zu behandeln.
*   **Performance von Reads/Writes:** Obwohl die `FileSystemWritableFileStream` und `FileSystemSyncAccessHandle` (im Web Worker Kontext) für hohe Leistung optimiert sind, müssen Sie sorgfältig mit großen Dateien umgehen und asynchrone Vorgänge vermeiden, die zu Engpässen führen könnten. Die `getFile()`-Methode liefert einen Schnappschuss der Datei, der **nicht mehr lesbar ist, wenn die Datei extern geändert wurde**; Sie müssen `getFile()` erneut aufrufen, um die neuen Daten zu erhalten.
*   **Zukünftige Iteration (DB $\rightarrow$ Local):** Wenn Sie später Änderungen von der Datenbank zum lokalen Dateisystem übertragen möchten, müssen Sie sicherstellen, dass diese **"Push-down"-Logik** nicht in Konflikt mit den Schreibvorgängen des externen Editors gerät (Race Conditions). Die Datenbank-Änderungen könnten über Phoenix PubSub oder Ash Notifiers an die LiveView-Clients gesendet werden, um den Browser zu benachrichtigen, dass er die lokale Datei aktualisieren muss.

***

Diese Implementierung ist wie der Bau einer **doppelten Tür** für Ihr Notizsystem: Einerseits können Benutzer ihre bevorzugten, robusten externen Werkzeuge (die lokalen Editoren) nutzen, um auf die Notizen zuzugreifen. Andererseits fungiert die Webanwendung als Wächter, der dank der Browser-API und LiveView sicherstellt, dass alle durch diese Tür eintretenden Änderungen sofort mit der zentralen, organisierten Datenbank synchronisiert werden. Die Herausforderung besteht darin, sicherzustellen, dass die Tür immer offen und die Synchronisation sofort und zuverlässig ist.


---
Die Persistenz von Handles in Webanwendungen, die die File System Access API (FSA API) nutzen, basiert auf der **Serialisierbarkeit** dieser Objekte.

Hier sind die zentralen Punkte zur persistenten Speicherung von Handles:

1.  **Serialisierbarkeit der Handles:**
    Die Objekte, die eine Datei oder ein Verzeichnis im System des Benutzers repräsentieren – nämlich `FileSystemHandle` sowie seine Kind-Schnittstellen **`FileSystemFileHandle`** und **`FileSystemDirectoryHandle`** – sind als **serialisierbare Objekte** (`Serializable`) gekennzeichnet. Dies ist die Grundvoraussetzung für ihre Speicherung.

2.  **Speicherort: IndexedDB:**
    Um Handles persistent zu speichern, können Objekte, die auf `FileSystemHandle` basieren, in eine **IndexedDB-Datenbankinstanz** serialisiert werden.
    Es wurde explizit festgestellt, dass man Handles nicht im `local storage` (lokalen Speicher) oder ähnlichem speichern kann, weshalb die Handles für das Dateisystem in einer **eigenen IndexedDB** gespeichert werden.

3.  **Zweck der Speicherung:**
    Die Speicherung des `FileSystemHandle` (typischerweise eines `FileSystemDirectoryHandle` für eine Notizen-App) in IndexedDB dient dazu, den Zugriff auf das Dateisystem über mehrere Sitzungen hinweg **wiederherzustellen**, ohne den Benutzer erneut zur Auswahl des Verzeichnisses aufzufordern. Nach dem Abrufen des Handles aus IndexedDB muss die Anwendung jedoch die Berechtigungen mit `queryPermission()` überprüfen und bei Bedarf mit `requestPermission()` **erneut anfordern**.

4.  **Übertragung:**
    Neben der Speicherung in IndexedDB können Handles auch über die Funktion **`postMessage()`** übertragen werden.

Der technische Hintergrund der Serialisierung in IndexedDB ist, dass ein `FileSystemHandle` ein `locator` (eine Dateisystemlokalisierung) zugeordnet ist, der wiederum den `root` (die Dateisystem-Wurzel) und den `path` (Pfad) enthält. Während der Serialisierung wird der `locator` zusammen mit der Origin der Anwendung gespeichert. Bei der Deserialisierung wird der `locator` wiederhergestellt, was den Zugriff auf die ursprüngliche Datei oder das Verzeichnis ermöglicht, sofern die Berechtigungen (Permissions) noch gültig sind.

---
Die Entwicklung dieses Proof of Concept (PoC) konzentriert sich hauptsächlich auf die Choreografie zwischen dem Frontend (Browser-JavaScript mit der File System Access API) und Ihrem LiveView-Backend.

Hier sind die detaillierten ersten Schritte, um diese Funktionalität zu implementieren, einschließlich der Verwendung des experimentellen `FileSystemObserver`.

---

### Phase 1: Frontend-Aktivierung und Dateierstellung

Dieser Schritt beinhaltet das Auslösen der Funktion über einen Benutzerklick (da die File System Access API (FSA API) eine **Benutzergeste** in einem **sicheren Kontext (HTTPS)** erfordert) und das erstmalige Schreiben der Notizdaten in das lokale Dateisystem.

#### 1. Elixir/LiveView: Die Schaltfläche und das Event

Im Elixir-Code (LiveView-Template) definieren Sie eine Schaltfläche, die ein Event auslöst und die notwendigen Daten (ID und Inhalt) an das Frontend sendet.

```html
<div id="note-<%= @note.id %>" phx-hook="LocalEditor" 
     data-note-id="<%= @note.id %>" 
     data-note-content="<%= @note.content %>">
  
  <h1><%= @note.title %></h1>
  
  <button phx-click="request_local_edit" 
          phx-value-content="<%= @note.content %>"
          phx-target="<%= @myself %>">
    Edit locally
  </button>
  
  <%# Hier würde der Inhalt der Note gerendert werden %>
  <p><%= @note.content %></p>
</div>
```

*Anmerkung:* Der `phx-hook` (z. B. `LocalEditor`) ist notwendig, um die komplexe JavaScript-Logik der FSA API zu verwalten und die asynchrone Initialisierung durchzuführen.

#### 2. JavaScript: Handle abrufen und Datei schreiben

Der JavaScript-Hook muss auf das Benutzer-Event reagieren, um das Verzeichnis auszuwählen und die Datei zu erstellen.

```javascript
// Innerhalb Ihres LiveView-Hooks (z.B. LocalEditor)

async createLocalNote(noteId, content) {
    try {
        // 1. Benutzer zur Auswahl eines Verzeichnisses auffordern
        // Dies muss durch die Benutzergeste (Klick) ausgelöst werden.
        const dirHandle = await window.showDirectoryPicker(); //

        // 2. Dateiname definieren und Handle abrufen
        // Wir verwenden die ID, um die Datei eindeutig zu identifizieren.
        const fileName = `${noteId}.md`;
        const fileHandle = await dirHandle.getFileHandle(fileName, { create: true }); //
        
        // 3. Schreibvorgang starten
        const writable = await fileHandle.createWritable(); //
        
        // 4. Inhalt schreiben
        await writable.write(content); //
        
        // 5. Stream schließen, um die Daten auf die Festplatte zu schreiben
        await writable.close(); // Dies ist zwingend erforderlich
        
        console.log(`File created at: ${fileName}`);

        // OPTIONAL: FileHandle in IndexedDB speichern, um es persistent zu machen
        // ... (IndexedDB persistence logic)
        
        // 6. Beobachtung starten (siehe Phase 2)
        this.setupFileObserver(fileHandle);
        
    } catch (error) {
        console.error("Local file access failed:", error);
        // LiveView benachrichtigen, dass der Vorgang fehlgeschlagen ist
        this.pushEvent("local_edit_failed", { error: error.message });
    }
}
```

### Phase 2: Änderungen überwachen (`FileSystemObserver`)

Um die Änderungen zu erkennen, die ein externer Editor vornimmt, verwenden Sie, wie gewünscht, den **experimentellen** `FileSystemObserver`.

> **ACHTUNG:** Die `FileSystemObserver`-API ist **experimentell** und **nicht standardisiert**. Die Quellen raten davon ab, nicht standardisierte Funktionen in der Produktion zu verwenden, da die Browserunterstützung begrenzt sein kann. Für ein PoC ist es jedoch ein geeigneter Ansatz.

#### 3. JavaScript: Observer initialisieren und Callback definieren

Dieser Code wird ausgeführt, nachdem `createLocalNote` erfolgreich ein `fileHandle` zurückgegeben hat:

```javascript
// Innerhalb des LiveView-Hooks
setupFileObserver(fileHandle) {
    if (typeof FileSystemObserver === 'undefined') {
        console.warn("FileSystemObserver is not supported. Consider using Polling.");
        // Hier müsste eine Fallback-Lösung (Polling) implementiert werden
        return;
    }

    const liveSocket = this.liveSocket; // Zugriff auf die LiveSocket-Instanz

    const observerCallback = (records, observer) => { //
        for (const record of records) {
            console.log("Change detected:", record);
            
            // Wir prüfen, ob es sich um unser relevantes Handle handelt
            // (Alternativ könnte man den Observer nur auf dieses eine Handle ansetzen)
            if (record.type === 'changed' && record.changedHandle.kind === 'file') { 
                
                // 1. Lese den neuen Inhalt der Datei
                record.changedHandle.getFile()
                    .then(file => file.text())
                    .then(newContent => {
                        
                        const noteId = fileHandle.name.replace(".md", ""); // ID extrahieren

                        // 2. Sende die aktualisierten Daten an den LiveView-Backend
                        // Wir verwenden pushEvent, um ein Event an LiveView zu senden
                        liveSocket.pushEvent("local_content_updated", {
                            id: noteId,
                            content: newContent
                        });
                        
                        console.log(`Sent updated content for ID: ${noteId}`);
                    })
                    .catch(e => console.error("Error reading file content:", e));
            }
        }
        // Optional: Wenn der Observer nur einmal feuern soll, observer.disconnect();
    };
    
    // Observer instanziieren
    const observer = new FileSystemObserver(observerCallback);
    
    // Beobachtung des spezifischen Datei-Handles starten
    observer.observe(fileHandle); 
    this.localObserver = observer; // Referenz speichern, um später disconnect() aufrufen zu können
}
```

### Phase 3: Backend-Synchronisation (LiveView $\rightarrow$ Ash)

Der LiveView-Prozess empfängt das Event und leitet die Änderung zur Speicherung in der Datenbank an den Ash-Layer weiter.

#### 4. Elixir/LiveView: Event-Handler implementieren

Die LiveView-Instanz muss das vom Frontend gesendete `local_content_updated`-Event behandeln (`handle_event/3`).

```elixir
def handle_event("local_content_updated", %{"id" => id, "content" => content}, socket) do
  # 1. Note über die ID abrufen (Ash Read Action)
  case Tunez.Music.get_note_by_id(id, actor: socket.assigns.current_user) do #
    {:ok, note} ->
      # 2. Note aktualisieren (Ash Update Action)
      # Wir nehmen an, dass 'content' ein akzeptiertes Attribut in der Note-Resource ist
      changeset = Ash.Changeset.for_update(:update, note, %{content: content})
      
      case Ash.update(changeset) do
        {:ok, _updated_note} ->
          # Erfolgsmeldung, die dank LiveView reaktiv an den Client gesendet wird
          {:noreply, put_flash(socket, :info, "Note successfully synchronized from filesystem.")}
          
        {:error, %{errors: errors}} ->
          # Fehler beim Speichern (z.B. Validierung durch Ash)
          {:noreply, put_flash(socket, :error, "Database update failed: #{inspect(errors)}")}
      end
      
    {:error, _reason} ->
      {:noreply, put_flash(socket, :error, "Note not found or unauthorized.")}
  end
end
```

Dieser Code demonstriert, wie LiveView die asynchrone Echtzeitkommunikation vom Browser entgegennimmt und die Geschäftslogik (die in diesem Fall die **C**reate, **R**ead, **U**pdate, **D**estroy-Operationen, oder **CRUD**, auf die Ressource abbildet) an Ash delegiert, um die Daten sicher und mit der definierten Logik in die Datenbank zu schreiben.



---

I have a question about this when the client side part is talking to a 
LiveView to inform the server about changes, doesn't that mean that
the user can not change the page when editing a note in an external editor?
Ideally it should be possible to edit multiple notes in an external Editor
and be able to send updates even when navigating in the browser.

Would that be possible? What needs to be done to support that?


