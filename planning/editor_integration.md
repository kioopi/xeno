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

* **Sicherer Kontext:** Die FSA API ist nur in **sicheren Kontexten (HTTPS)** verfügbar.
* **Benutzergeste:** Der Zugriff auf das lokale Dateisystem, insbesondere das Öffnen eines Verzeichnisauswahlfensters (`showDirectoryPicker`), muss durch eine **Benutzergeste** (wie einen Klick auf eine Schaltfläche) ausgelöst werden.
* **Verzeichnis-Handle abrufen:** Sie müssen `Window.showDirectoryPicker()` verwenden, um den Benutzer aufzufordern, das Stammverzeichnis der Notizen auszuwählen. Dies gibt Ihnen ein `FileSystemDirectoryHandle` zurück, welches den Zugriff auf die Verzeichnisstruktur ermöglicht.
* **Persistenz und Berechtigungen:** Die erteilten Berechtigungen sind nicht immer dauerhaft. Um den Zugriff über Sitzungen hinweg aufrechtzuerhalten, müssen Sie das `FileSystemDirectoryHandle`-Objekt in einer Datenbank speichern, die die Serialisierung unterstützt, typischerweise in **IndexedDB**. Bei der Wiederherstellung der Anwendung müssen Sie die Berechtigung mithilfe von `queryPermission()` überprüfen und gegebenenfalls mit `requestPermission()` **erneut anfordern**.

#### 2. Erstellen der lokalen Kopie

* **Verzeichnisstruktur abbilden:** Da Ihre App eine Verzeichnisstruktur für Notizen verwendet, müssen Sie diese Struktur (die in Ihrer Ash-Datenbank gespeichert ist) lokal neu erstellen, indem Sie das `FileSystemDirectoryHandle` rekursiv durchlaufen.
* **Verzeichnisse erstellen:** Verwenden Sie die Methode `getDirectoryHandle(name, {create: true})` für Ordner.
* **Dateien erstellen/schreiben:** Um die Markdown- oder TXT-Dateien zu erstellen, verwenden Sie `getFileHandle(name, {create: true})`.
* **Inhalte schreiben:** Zum Schreiben in die Datei müssen Sie einen beschreibbaren Stream erstellen (`fileHandle.createWritable()`). Der Schreibvorgang erfolgt asynchron über `writableStream.write(contents)` (wobei `contents` ein `Blob`, `String` oder `Buffer` sein kann). **Wichtig:** Sie müssen `await writableStream.close()` aufrufen, um die Datei zu schließen und die Inhalte tatsächlich auf die Festplatte zu schreiben.

#### 3. Änderungen im Dateisystem überwachen

Dies ist ein kritischer und potenziell herausfordernder Teil, da Sie Änderungen erkennen müssen, die von externen Editoren vorgenommen wurden.

* **Der FileSystemObserver (Experimentell):** Die Schnittstelle `FileSystemObserver` bietet einen Mechanismus, um Änderungen an ausgewählten Dateien oder Verzeichnissen zu beobachten. Dies würde verhindern, dass Ihre Webanwendung das Dateisystem ständig abfragen muss.
  * **Herausforderung:** Die `FileSystemObserver`-API ist derzeit als **experimentell** und **nicht standardisiert** gekennzeichnet. Es wird **nicht empfohlen**, nicht standardisierte Funktionen in der Produktion zu verwenden, da sie eine begrenzte Browserunterstützung haben und sich ändern oder entfernt werden können.
* **Alternative: Polling:** Eine alternative Strategie, die in einem ähnlichen Projekt angewendet wurde, ist das **regelmäßige Polling** (z. B. 10 Mal pro Sekunde) der Dateien auf Änderungen. Bei Erkennung einer Änderung wird der aktuelle Inhalt in die Datenbank gespeichert.
* **Implementierung (bei Änderung):** Wenn eine Änderung erkannt wird (entweder durch Observer oder Polling):
    1. Die Anwendung muss den neuen Inhalt der geänderten Datei abrufen. Dies geschieht durch erneutes Aufrufen von `fileHandle.getFile()` und anschließendes Auslesen des Inhalts (z. B. `file.text()` für Textdateien).
    2. Die gelesenen Inhalte müssen dann zur Datenbank-Aktualisierung an den Elixir/LiveView-Backend gesendet werden.

---

### gration (Elixir/Phoenix/Ash)

Die Integration in Ihren Elixir/Ash/Phoenix/LiveView-Stack beinhaltet die effiziente Verarbeitung der vom Browser gesendeten Änderungen und deren Speicherung in der Datenbank.

#### 1. Kommunikation Browser $\rightarrow$ LiveView

* **Ereignis-Handling:** Die asynchrone JavaScript-Logik, die die Dateiänderungen erkennt, muss ein Ereignis an die LiveView-Instanz senden. Dies geschieht typischerweise über LiveView-Ereignis-Handler (`handle_event/3`) oder durch das Senden von Nachrichten (`handle_info/2`), die durch clientseitige Hooks ausgelöst werden.
* **Nutzlast:** Die gesendete Nachricht muss die identifizierende Information der Notiz (z. B. ID oder Pfad) sowie den **vollständigen, aktualisierten Inhalt** der Markdown/TXT-Datei als String enthalten.

#### 2. Datenverarbeitung und Speicherung (Ash)

* **Domänenmodell:** Sie verwenden Ash, um Ihr Domänenmodell (die `Note` Ressource) zu beschreiben, einschließlich ihrer Attribute und der Verzeichnisstruktur.
* **Aktionen und Changesets:** LiveView sendet die Nutzlast an Ihren Ash-Layer. Die Aktualisierung der Notiz in der Datenbank erfolgt über eine Ash-Update-Aktion (z. B. `:update`).
  * Ash verwendet `Changesets` zur sicheren Validierung und Verarbeitung von Daten. Wenn Sie die Änderung (den neuen Inhalt) übergeben, wird ein Changeset erstellt und die hinterlegte Geschäftslogik (Validierungen, etc.) ausgeführt.
  * Wenn Sie das gesamte `Note` Objekt als String speichern, wird dieser String in die Datenbank persistiert.

#### 3. Überlegungen zur Verzeichnisstruktur und Pfaden

* **Pfad-Mapping:** Da die FSA API hauptsächlich mit Handles arbeitet und die direkte Verwendung traditioneller Pfade (`foo/bar/bleh.txt`) kompliziert sein kann, müssen Sie im JavaScript sicherstellen, dass Sie die **eindeutige ID** oder den **relativen Pfad** (den Sie mit `directoryHandle.resolve()` abrufen können) einer geänderten Datei bestimmen und an den Elixir-Backend übermitteln, damit die richtige `Note` in der Datenbank aktualisiert werden kann.

### III. Potenzielle Herausforderungen und Einschränkungen

Zusätzlich zu den oben genannten Punkten sollten Sie Folgendes beachten:

* **Browser-Kompatibilität:** Derzeit wird die FSA API nicht von allen wichtigen Browsern unterstützt, insbesondere **Firefox und IE** bieten keine native Unterstützung (obwohl eine Polyfill-Bibliothek `browser-fs-access` existiert).
* **Umgang mit Fehlern:** Die API kann verschiedene Ausnahmen werfen, die oft komplex sind und von der Interaktion mit dem zugrunde liegenden Betriebssystem abhängen. Ihre JavaScript-Logik muss robust sein, um diese Fehler zu behandeln.
* **Performance von Reads/Writes:** Obwohl die `FileSystemWritableFileStream` und `FileSystemSyncAccessHandle` (im Web Worker Kontext) für hohe Leistung optimiert sind, müssen Sie sorgfältig mit großen Dateien umgehen und asynchrone Vorgänge vermeiden, die zu Engpässen führen könnten. Die `getFile()`-Methode liefert einen Schnappschuss der Datei, der **nicht mehr lesbar ist, wenn die Datei extern geändert wurde**; Sie müssen `getFile()` erneut aufrufen, um die neuen Daten zu erhalten.
* **Zukünftige Iteration (DB $\rightarrow$ Local):** Wenn Sie später Änderungen von der Datenbank zum lokalen Dateisystem übertragen möchten, müssen Sie sicherstellen, dass diese **"Push-down"-Logik** nicht in Konflikt mit den Schreibvorgängen des externen Editors gerät (Race Conditions). Die Datenbank-Änderungen könnten über Phoenix PubSub oder Ash Notifiers an die LiveView-Clients gesendet werden, um den Browser zu benachrichtigen, dass er die lokale Datei aktualisieren muss.

***

Diese Implementierung ist wie der Bau einer **doppelten Tür** für Ihr Notizsystem: Einerseits können Benutzer ihre bevorzugten, robusten externen Werkzeuge (die lokalen Editoren) nutzen, um auf die Notizen zuzugreifen. Andererseits fungiert die Webanwendung als Wächter, der dank der Browser-API und LiveView sicherstellt, dass alle durch diese Tür eintretenden Änderungen sofort mit der zentralen, organisierten Datenbank synchronisiert werden. Die Herausforderung besteht darin, sicherzustellen, dass die Tür immer offen und die Synchronisation sofort und zuverlässig ist.

---
Die Persistenz von Handles in Webanwendungen, die die File System Access API (FSA API) nutzen, basiert auf der **Serialisierbarkeit** dieser Objekte.

Hier sind die zentralen Punkte zur persistenten Speicherung von Handles:

1. **Serialisierbarkeit der Handles:**
    Die Objekte, die eine Datei oder ein Verzeichnis im System des Benutzers repräsentieren – nämlich `FileSystemHandle` sowie seine Kind-Schnittstellen **`FileSystemFileHandle`** und **`FileSystemDirectoryHandle`** – sind als **serialisierbare Objekte** (`Serializable`) gekennzeichnet. Dies ist die Grundvoraussetzung für ihre Speicherung.

2. **Speicherort: IndexedDB:**
    Um Handles persistent zu speichern, können Objekte, die auf `FileSystemHandle` basieren, in eine **IndexedDB-Datenbankinstanz** serialisiert werden.
    Es wurde explizit festgestellt, dass man Handles nicht im `local storage` (lokalen Speicher) oder ähnlichem speichern kann, weshalb die Handles für das Dateisystem in einer **eigenen IndexedDB** gespeichert werden.

3. **Zweck der Speicherung:**
    Die Speicherung des `FileSystemHandle` (typischerweise eines `FileSystemDirectoryHandle` für eine Notizen-App) in IndexedDB dient dazu, den Zugriff auf das Dateisystem über mehrere Sitzungen hinweg **wiederherzustellen**, ohne den Benutzer erneut zur Auswahl des Verzeichnisses aufzufordern. Nach dem Abrufen des Handles aus IndexedDB muss die Anwendung jedoch die Berechtigungen mit `queryPermission()` überprüfen und bei Bedarf mit `requestPermission()` **erneut anfordern**.

4. **Übertragung:**
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

Ja, das ist absolut möglich und notwendig, um die gewünschte Benutzererfahrung zu erreichen, bei der Benutzer die Seite wechseln können, während die lokale Bearbeitung aktiv bleibt.

Die Herausforderung, die Sie ansprechen, liegt im **Lebenszyklus von Phoenix LiveView-Prozessen**. Ein typischer LiveView-Prozess ist an die aktuell angezeigte Seite gebunden. Wenn der Benutzer navigiert, wird der zugehörige Prozess (und die WebSocket-Verbindung) normalerweise beendet, was die Dateisystemüberwachung im Browser-JavaScript stoppen würde.

Um dies zu umgehen, müssen Sie eine Architektur verwenden, die persistente Server-Side-Prozesse nutzt. Die Lösung im Phoenix/LiveView-Ökosystem ist die Verwendung von **Sticky LiveViews** oder **Sticky Live Components**.

Hier ist ein detaillierter Überblick über die notwendigen Schritte, um die Persistenz zu gewährleisten:

---

### I. Architekturwechsel: Einführung eines Sticky Components

Sie müssen die Logik, die für die Überwachung des lokalen Dateisystems verantwortlich ist, aus den Haupt-LiveViews der Notizen in eine **unabhängige, persistente Komponente** auslagern.

#### 1. Erstellen eines "Synchronisations-Agenten" (Sticky Component)

Erstellen Sie ein Live Component (z. B. `LocalSyncAgentLive`), dessen Hauptaufgabe es ist, die Verbindung zur Browser-API und die Datenbank-Synchronisation zu verwalten.

* **Implementierung als Sticky Component:** Diese Komponente muss in Ihrem Haupt-Layout **persistent** gerendert werden, indem die Option `sticky: true` verwendet wird. Dies stellt sicher, dass der Server-Prozess der Komponente aktiv bleibt und die zugehörige WebSocket-Verbindung (der "Kanal" zurück zum Browser) nicht getrennt wird, wenn der Benutzer im Browser navigiert (z. B. von `/notes/1` zu `/notes/2` oder zur Indexseite).

    ```elixir
    # Beispielhaft in einem Layout- oder Hauptmodul:
    <%= if @current_user do %>
      <%= live_render(@socket, MyApp.LocalSyncAgentLive, sticky: true, id: :local_sync_agent) %>
    <% end %>
    ```

* **Unabhängiger Status:** Sticky LiveViews sind vom übergeordneten LiveView-Prozess entkoppelt. Sie müssen ihren eigenen Zustand verwalten, einschließlich des Ladens des aktuellen Benutzers (z. B. mit einem `on_mount` Callback). Dies ist entscheidend, da der Agent die Berechtigung zur Aktualisierung der Ash-Datenbank benötigt.

#### 2. Verwaltung der lokalen Handles (Client-Seite)

Die Handles für die Verzeichnisse und Dateien, die Sie überwachen möchten, müssen sitzungsübergreifend persistent sein und im Browser verfügbar sein, unabhängig davon, welche LiveView-Seite gerade geladen wird.

* **Handles persistent speichern:** Die `FileSystemDirectoryHandle`-Objekte, die den Zugriff auf das lokale Notizverzeichnis gewähren, sind **serialisierbar**. Sie müssen diese Handles in der **IndexedDB** des Browsers speichern. Dies ermöglicht es der `LocalSyncAgentLive`-Instanz, die Handles wiederherzustellen, selbst wenn der Benutzer die Anwendung neu startet.
* **Wiederherstellung und Berechtigungen:** Bei der Initialisierung des JavaScript-Hooks des `LocalSyncAgentLive` versucht dieser, die Handles aus IndexedDB abzurufen und die gespeicherten **Berechtigungen erneut anzufordern/zu überprüfen**, da der Zugriff über Sitzungen hinweg nicht immer dauerhaft ist.

### II. Kommunikation und Synchronisation

Der Sticky Component übernimmt die gesamte Echtzeit-Kommunikation und die Backend-Synchronisation.

#### 3. Persistente Frontend-Überwachung

Das JavaScript im Browser muss die Überwachung (Polling oder `FileSystemObserver`) aufrechterhalten, solange die WebSocket-Verbindung zum **Sticky Component** aktiv ist:

* **Hook-Zuordnung:** Der JavaScript-Hook, der die FSA API verwendet und die Änderungen erkennt (siehe vorherige Schritte), wird an den `LocalSyncAgentLive` (Sticky Component) gebunden.
* **Ereignisse senden:** Wenn eine externe Änderung erkannt wird, sendet das JavaScript die aktualisierten Notizinhalte und die Notiz-ID an den Sticky Live Component-Prozess auf dem Server (z. B. mittels `pushEvent`).

#### 4. Datenbank-Aktualisierung (Ash)

Der Sticky Component empfängt die Änderungen im Elixir-Backend.

* **Event Handling:** Der `LocalSyncAgentLive` implementiert `handle_event/3`, um die vom Browser gesendeten Aktualisierungen zu empfangen.
* **Ash-Aktion:** Innerhalb dieses Handlers führt die Komponente die **Update-Aktion** für die entsprechende Notiz über Ihren Ash-Layer aus. Da der Sticky Component den `current_user` zugewiesen hat (siehe Punkt 1), kann er die Aktualisierung mit der korrekten Autorisierung durchführen.

#### 5. Echtzeit-Updates für die Benutzeroberfläche (PubSub)

Da der Sticky Component **keine direkte UI-Aktualisierung** vornimmt (er ist ja vom aktuellen Seiten-LiveView entkoppelt), muss er andere Komponenten oder Views informieren, falls diese die Notiz anzeigen:

* **Phoenix PubSub:** Nach einer erfolgreichen Aktualisierung im Ash-Layer sendet der Sticky Component eine **PubSub-Nachricht** über ein eindeutiges Thema (z. B. `note_updated:<note_id>`).
* **LiveView-Reaktion:** Jede LiveView-Instanz, die diese Notiz anzeigt (z. B. die `ShowLive` für die Notiz oder die Indexseite), muss diesen PubSub-Themen abonnieren (`Endpoint.subscribe`). Wenn die Nachricht eingeht, löst der Seiten-LiveView `handle_info/2` aus, um die Notiz erneut zu laden und die UI zu aktualisieren, wodurch sichergestellt wird, dass alle Benutzer, die die Notiz gerade im Browser anzeigen, die externe Änderung in **Echtzeit** sehen.

### Zusammenfassung der Notwendigkeiten

| Aufgabe | Technologie | Begründung/Details |
| :--- | :--- | :--- |
| **Persistenter Server-Prozess** | **Sticky Live Component/View** | Hält den Prozess und die WebSocket-Verbindung über Navigationswechsel hinweg aktiv, damit der Browser weiter überwachen kann. |
| **Persistenter Browser-Zugriff** | **IndexedDB** | Speichert die `FileSystemHandle` Objekte, um den lokalen Dateisystemzugriff sitzungsübergreifend wiederherzustellen. |
| **Asynchrone Überwachung** | **Browser JS (FSA API/Observer/Polling)** | Führt die eigentliche Überwachung im Browser durch, da nur dort Zugriff auf das lokale Dateisystem besteht. |
| **Echtzeit-Aktualisierung (UI)** | **Phoenix PubSub** | Broadcastet die Datenbankänderung von der persistenten Komponente an alle aktiven LiveViews, die die Notiz anzeigen. |

Durch die Auslagerung der Überwachungs- und Synchronisationslogik in einen Sticky Component stellen Sie sicher, dass der gesamte Synchronisationsmechanismus unabhängig von der aktuellen Browsernavigation im Hintergrund weiterläuft.

---

Read the document @planning/editor_integration_implementation.md
What are the next steps to implement a Proof of Concept for the editor integration feature?
Make a plan in a TDD style, lets keep it modular and maintainable.

---

## Better Metadata handling

So i've been thinking about the way we write the note metadata
(as returned by Sync.Exporter.to_json_metadata) like id and version into the filename.json file along with the note data and tags.

First point: The data field of a Note is not really metadata.
It can contain all kinds of user content.

Second point: The filename.json now contains data that the user should not
be able to edit like id, version, and timestamps.

We should find a way to have access to the note attributes we need for
the import, without exposing them to the user.

Now I'm thinking to keep track of all exported Notes in indexDB. Every Note could have a record there with the id and version attributes. These could then be used to complete the data needed for the import.
The version then gets updated when the import succeeds. This also fixes the current problem that after importing files once the version is stale and all subsequent imports fail because the version in the json file is lower than the one in the database.

Maybe we can even change the format of the data that send to the server to be pretty much the same as the arguments for the update action of the Note. This would enable us to remove some data massaging in elixir and feel more familiar to the developers working with the code.

Please think about this. Analyze the current implementation. Does this sound like a good idea? What are the pros and cons?

--

The data attribute of a Note is typically user content.
It might end up being mostly edited through interfaces in the app
offered by NoteTypes but power users might want to edit the raw data
in their editor or via scripts.
So the filename.json should stay and contain user editable data.

The use-case of having a work and home computer using the same
notes is real.
The checked out files should be as close to regular files as possible.
The "magic" syncing to Xeno should interfere as little as possible with
whatever the user wants to do with the files.
So when a user just drag-and-drops the files somewhere and loses
the version attributes conflict resolution (next paragraph) could
save the day.

The proper conflict resolution will come in a later iteration.
For now failing is alright. Later there will be an overwrite or re-fetch option.
Later there might be some kind of notification when editing a stale note.
Maybe even smarter resolution strategies via CRDT.

We don't need any data migration for now. There are no real users yet.

So here is what i'm thinking:
It would be good to remove the version from filename.json.
This is because the version needs to be updated after every change to the Note.
If a user edits both .json and .md but only saves .md we would have to edit
an unsaved .json file. This seem not ideal.
So version has to go into IndexDB or some other storage. We're already using IndexDB so that is probably fine.
If we keep the id in the .json referencing the version will be simple.
So we still have the problem that a user might accidentally edit the
id.
Here hare some ideas:
_id is a good start to mark the field as read-only.
We could duplicate the id in .md in the frontmatter. This way we can check
if both id are the same. Actually three .json, .md, and indexdb. And warn the
if there is a discrepancy.
Another idea would be to remove the id from .json and add another file
filename.id or .filename.id that only contains the id. This might keep it
relatively save from accidental edits but the file would have to be carried
along and be considered.

So what do you think? Can you summarize the state of our discussion here?
Please analyze the pros and cons of these ideas and feel free to add your
own. Advise on an architecture that will give the user freedom to use
the system as they like while keeping it stable, reliable and maintainable.

---

Read the document @planning/metadata_architecture.md
Compare it to the current state of the implementation.
What are the next steps in the development?
Make a plan in a TDD style, lets keep it modular and maintainable.

Update @planning/metadata_architecture.md to reflect the current
state of development

🔄 Complete Flow (Frontend → Backend → Frontend)

1. Frontend: Auto-fix detects conflict
   ↓
2. Frontend: Emits "id_conflict" event to backend
   ↓
3. Backend: Stores conflict in socket state
   ↓
4. Backend: (Future) Renders conflict dialog UI
   ↓
5. User: Chooses which ID to use
   ↓
6. Frontend: Emits "resolve_conflict" with choice
   ↓
7. Backend: Emits "resolve_conflict" back to frontend
   ↓
8. Frontend: FileSystemHook applies chosen ID
   ↓
9. Frontend: Retries import with corrected ID
   ↓
10. Success! ✅

📋 Event Communication Diagram
Frontend (FileSystemHook)          Backend (SyncLive)
─────────────────────────          ──────────────────

import_files ──────────────────→   handle_event("import_files")
                                         ↓
                                    Process imports
                                         ↓
                                    Detect id_not_found error
                                         ↓
                 ←───────────────── push_event("import_result")
      ↓
Auto-fix handler runs
      ↓
Check: Server + IndexedDB agree?
      ├─ Yes: Auto-fix ✅
      └─ No: Conflict ⚠️
           ↓
id_conflict ─────────────────────→  handle_event("id_conflict")
                                          ↓
                                     Store conflict in state
                                          ↓
                                     [User sees UI dialog]
                                          ↓
                                     User clicks "Use Server ID"
                                          ↓
resolve_conflict ────────────────→  handle_event("resolve_conflict")
                                          ↓
                 ←────────────────── push_event("resolve_conflict")
      ↓
Apply chosen ID
      ↓
Retry import ─────────────────────→
                                         ↓
                 ←────────────────── Success! ✅

---

Read the documents

@planning/editor_integration_implementation.md
@planning/metadata_architecture.md

We've been working on editor integration but took a detour to
revisit the metadata handling for the filesystem integration.

Analyse and understand the current state of the implementation.

What are the next steps in the development?

Make a plan in a TDD style, lets keep it modular and maintainable.

---

@planning/metadata_architecture.md

Why is the path the primary key in NoteMetadataStore?
Wouldn't we usually look up Notes by their id from the .json file?
Only if there is an id mismatch between client and server we'd need
to look up a Note in NoteMetadataStore by path, right?

---

Sync.TreeBuilder.note_file_path
Sync.Importer.find_note_by_path
seem to duplicate futest/xeno/sync_test.exsnctionality.
This should probably move into the Note resource.
There could be a calculation "file_path" on note
that returns the filename with path without extension.
This will make it easy to write a read action by_path.
The knowledge how file paths work will be centralized
in Note.
Read the relevant files and analyze how we can move domain
logic into resources to get more idiomatic Ash.
Think about Calculations, Aggregates, and Actions.
Analyse and advise.

Lets revisit Xeno.Sync.Importer

parse_metadata seems unused
parse_file_pathlib/xeno_web/live/sync_live.ex seems unused

many of the other responsibilities in this file seem to be good fits to move
into Ash resources.

parse_markdown could be a Change

the validations of id and version should become Ash Validation

i'm not sure that verify_version is really needed because Ash
provides this functionality.

So i'm thinking
if we change the file_system_hook to call import_files not with
{ note_id, markdown_content, metadata }
but with an object that looks like this
{ id, nane, text, version, data, tags }
We can add a update action to the Note resource that does all the
work that is being done in Importer.

Please analyse these suggestion and look at the code to see if this
will work. I think it will make the code mode idiomatic Ash and
will let us take advantage of Ash features like validations
and optimistic locking.

---

Some attempts have been made in the codebase include everything that
to be done for the import of filesystem changes into
the import_from_filesystem ash action on Note.
This would conform to Ash philosophy see:
<https://hexdocs.pm/ash/actions.html#idiomatic-actions>

The idea seems to be to move the resolution of mismatching id and path
into a validation that runs in the action and make path a required
argument of the action.
If this could become a regular update action it might even be possible
to use bulk updates.

Please look at the changes in the last commit, run the tests and
get and overview of the codebase and the changes.

Please analyse the ideas and problems here and advise on the next steps.

----

Interesting points.

But Ash actions also have the concepts of before_transaction and
before_action hooks that are explicitly for things like calling
APIs or complex logic. I think Ash expects some amount of
business logic in its actions. Doing it in a service layer
would take some of the domain modeling out of Ash.

Also there are Ash custom errors which could be used to
return all the data needed to resolve the conflicts

<https://hexdocs.pm/ash/error-handling.html>
<https://hexdocs.pm/ash/Ash.Error.html#to_ash_error/3>

---

### Notes on the implementation so far

We will work on these step-by-step when the time is ready.

Sync.TreeBuilder.note_file_path should become a calculation on Note.
The different extensions .md .json need graceful handling.
Done [x]

Sync.Exporter.to_json_metadata could also become a calculation.
Notes in json format might be needed in other features as well.
Then again i guess Ash Rest API will probably bring its own json encoder.

Documentation needed in SyncLive.
Especially the push_event calls to communicate with the javascript client.

SyncLive eventhandler export_all calls Note.get for every note,
this should be one database query.
Also all that export_note then does is json encoding. If we can move
that into a calculation with a postgres expression this can be
one database call and no iteration.

Can we write the hook and directory_handle_store.js in TypeScript? Yes. [x]

Check optimistic locking impl for FS import.

Add TypeScript type check to precommit and compile?

We probably need a dedicated typescript test suite. [x]

Add playwright tests for syncing (if possible)

When import fails there is only a Flash message saying "failed: 2"
this needs a more helpful error message

Wants: How to see which mix packages docs are fetched with mix hex.docs?
Wants: Task to fetch all docs after update.

Update directory_handle_store.ts to use idb?
Add vitest tests for directory_handle_store.ts

Change the format send to the server by the sync system to be closer
to the note resource format.
But still: Add a dedicated action to update notes from fs sync.

Add a script to run elixir and js tests

Update @AGENTS.md with information about TypeScript testing.

Why are name, tags, data arguments for import_from_filesystem and update_from_fs
and not accepts?

The console output in file_system_hook should only be displayed when
MIX_ENV is "dev". For that we need to find out how to access MIX_ENV
from javascript.
