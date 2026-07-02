# RogueMon Streamer Extension - Setup & Installation Guide / Guida d'Installazione

---

## 🇬🇧 English Setup Guide

### ⚙️ Prerequisites
Before getting started, ensure you have the following ready:
1. **BizHawk Emulator & RogueMON ROM**:
   * Refer to the official [RogueMON Setup Video Guide by Crozwords](https://www.youtube.com/watch?v=26D8A1NCgCU) to configure your emulator, tracker, and game files.
2. **Streamer.bot**:
   * Download the latest version of Streamer.bot from the [official website](https://streamer.bot/).

---

### 🛠️ Step-by-Step Installation

#### Step 1: Streamer.bot Twitch Connection Setup
1. Launch **Streamer.bot** and connect it to your Twitch Broadcaster/Bot accounts.
2. Refer to the [Streamer.bot Twitch Setup Guide](https://docs.streamer.bot/get-started/setup#twitch-setup) if you need help linking your account.

#### Step 2: Establish the Connection Between Ironmon-Tracker and Streamer.bot
1. Run your RogueMON game in BizHawk and launch the Ironmon-Tracker script.
2. Open the Tracker Settings (gear icon) -> select the **Streaming** section -> click **Stream Connect**.
3. Under the **Status** menu, click **Connection Folder** and select the **`data`** folder located inside your extracted Streamer.bot files (e.g. `C:\Streamer.bot\data\`).
4. Click **Import Code** in the tracker.
5. In Streamer.bot, click **Import** (top left menu), paste the copied code string, check all imported actions under the `Tracker Integration` group, and click **Import**.
6. **Important**: Completely restart **Streamer.bot** so it registers the imported connection structures.
7. Click the **Connect** button inside the tracker.
   * *Troubleshooting*: If it does not show `Online. Connection established`, close the tracker Lua script in BizHawk, restart it, and navigate back to **Streaming** -> **Stream Connect** to verify the online status.

#### Step 3: Configure Streamer.bot Actions and Triggers
1. Go to the **Actions** tab in Streamer.bot.
2. Under the **Tracker Integration** action group, select **`RogueMON Streamer Event`**.
3. In the bottom-right panel (**Sub-Actions**), configure the two sub-actions:
   * **Set Argument**:
     * Right-click inside the panel and select **Add -> Core -> Arguments -> Set Argument**.
     * Set **Variable Name** to `trackerNetworkPath`.
     * Set **Value** to the absolute path of your Streamer.bot's `data` folder (e.g. `C:\Streamer.bot\data\`). **Important**: Make sure it ends with a trailing backslash `\`.
   * **Execute C# Code**:
     * Right-click inside the panel and select **Add -> Core -> C# -> Execute C# Code**.
     * Double-click the newly created sub-action to open the C# Editor.
     * Copy the C# script code shown below and paste it into the editor.
     * **Important**: Inside the script, locate the path fallback (search for `YOUR_STREAMERBOT_PATH`):
       `: @"C:\YOUR_STREAMERBOT_PATH\data\";`
       Replace `"C:\YOUR_STREAMERBOT_PATH\data\"` with the correct absolute path to your Streamer.bot `data` folder (matching the path you configured in the *Set Argument* sub-action).
     * Click **Compile** to compile the C# script (verify the **Compiling Log** says **Compiled successfully**), then click **Save and Compile**.

For reference, here is the script code:
```csharp
using System;
using System.IO;
using System.Collections.Generic;
using Newtonsoft.Json;

public class CPHInline
{
    public bool Execute()
    {
        try
        {
            string connectionFolder = args.ContainsKey("trackerNetworkPath") 
                ? args["trackerNetworkPath"].ToString() 
                : @"C:\YOUR_STREAMERBOT_PATH\data\";

            if (!connectionFolder.EndsWith("\\")) connectionFolder += "\\";
            string filePath = connectionFolder + "Tracker-Requests.json";

            string username = "Anonymous";
            if (args.ContainsKey("user") && args["user"] != null)
            {
                username = args["user"].ToString();
            }

            string rewardName = "";
            if (args.ContainsKey("rewardName") && args["rewardName"] != null)
            {
                rewardName = args["rewardName"].ToString();
            }
            else if (args.ContainsKey("rewardTitle") && args["rewardTitle"] != null)
            {
                rewardName = args["rewardTitle"].ToString();
            }

            var request = new Dictionary<string, object>();
            request["GUID"] = Guid.NewGuid().ToString();
            request["CreatedAt"] = (long)(DateTime.UtcNow - new DateTime(1970, 1, 1)).TotalSeconds;
            request["Username"] = username;
            request["Platform"] = "twitch";

            if (!string.IsNullOrEmpty(rewardName))
            {
                request["EventKey"] = "TwitchChannelPointsEvent";
                request["Args"] = new Dictionary<string, object>
                {
                    { "EventName", rewardName }
                };
                CPH.LogInfo($"[RogueMon Streamer] Channel Points: {username}, Reward: {rewardName}");
            }
            else
            {
                if (args.ContainsKey("fromGiftBomb"))
                {
                    try {
                        if (Convert.ToBoolean(args["fromGiftBomb"])) {
                            CPH.LogInfo("[RogueMon] Ignored individual Gift Sub belonging to a Gift Bomb.");
                            return true;
                        }
                    } catch {}
                }

                bool isGift = false;
                if (args.ContainsKey("isGift") && args["isGift"] != null)
                {
                    try {
                        isGift = Convert.ToBoolean(args["isGift"]);
                    } catch {
                        isGift = false;
                    }
                }

                string eventType = args.ContainsKey("event") ? args["event"].ToString() : "";
                if (eventType.Contains("Gift") || eventType.Contains("Bomb"))
                {
                    isGift = true;
                }

                int subCount = 1;
                string[] countKeys = new string[] { "gifts", "giftCount", "recipientCount" };
                foreach (var key in countKeys)
                {
                    if (args.ContainsKey(key) && args[key] != null)
                    {
                        try {
                            subCount = Convert.ToInt32(args[key]);
                            isGift = true;
                            break;
                        } catch {}
                    }
                }

                if (subCount == 1) {
                    if (args.ContainsKey("amount") && args["amount"] != null) {
                        try { subCount = Convert.ToInt32(args["amount"]); } catch {}
                    } else if (args.ContainsKey("count") && args["count"] != null) {
                        if (isGift) {
                            try { subCount = Convert.ToInt32(args["count"]); } catch {}
                        }
                    } else if (args.ContainsKey("input") && args["input"] != null && !string.IsNullOrWhiteSpace(args["input"].ToString())) {
                        try {
                            int.TryParse(args["input"].ToString().Split(' ')[0], out subCount);
                        } catch {}
                    }
                }

                string tier = "Tier 1";
                if (args.ContainsKey("subTier") && args["subTier"] != null)
                {
                    tier = args["subTier"].ToString();
                }

                request["EventKey"] = "TwitchSubEvent";
                request["Args"] = new Dictionary<string, object>
                {
                    { "SubCount", subCount },
                    { "IsGift", isGift },
                    { "Tier", tier }
                };
                CPH.LogInfo($"[RogueMon Streamer] Subscription: {username}, Subs: {subCount}, Gift: {isGift}");
            }

            List<Dictionary<string, object>> requests = new List<Dictionary<string, object>>();
            if (File.Exists(filePath))
            {
                string existingJson = File.ReadAllText(filePath);
                if (!string.IsNullOrWhiteSpace(existingJson))
                {
                    requests = JsonConvert.DeserializeObject<List<Dictionary<string, object>>>(existingJson) 
                        ?? new List<Dictionary<string, object>>();
                }
            }

            requests.Add(request);
            string newJson = JsonConvert.SerializeObject(requests, Formatting.Indented);
            File.WriteAllText(filePath, newJson);
            
            return true;
        }
        catch (Exception ex)
        {
            CPH.LogError("RogueMON write error: " + ex.ToString());
            return false;
        }
    }
}
```

4. In the top-right panel (**Triggers**), link your Twitch events:
   * **Subscription triggers**: Right-click -> **Twitch** -> **Subscriptions** -> Add **Subscription**, **Re-Subscription**, **Gift Subscription**, and **Gift Bomb**.
   * **Channel Point triggers**: Right-click -> **Twitch** -> **Channel Reward** -> **Reward Redemption** -> Select your custom Twitch Channel Point reward.
> [!IMPORTANT]
> **Twitch Channel Point Reward Title Requirement**: The title of the reward on your Twitch creator dashboard **MUST** contain the exact name of the event you wish to trigger (case-insensitive, e.g., "Roguemon - Let's Dance" or "RogueMON - Restore HP"). Otherwise, the connection cannot parse the event and it will fail to activate.

#### Step 4: Install and Activate the RogueMon Streamer Extension
1. Extract the zip file directly into the `extensions` folder of your Ironmon-Tracker installation directory.
2. In the tracker, open Settings (gear icon) -> click **Extensions** -> select **General** tab.
3. Click **Install a new extension**, navigate to your extensions folder, select `roguemon-streamer-extension`, and install it.

#### Step 5: Options, Testing, and Troubleshooting
1. Open the RogueMon Streamer extension's options tab to configure which pools to listen to: **Twitch Subs only**, **Channel Points only**, or both.
2. If you want to test events or run simulations, use the dedicated test screen within the extension settings.
3. You can also view statistics to track remaining turn durations, configure sub counts, or adjust milestones.
4. **Troubleshooting**: If the extension behaves unexpectedly or you need to clear the request queue, click the **Reset** button. This instantly clears all queued events and resets all active streamer run variables back to 0.

---

## 🇮🇹 Guida d'Installazione in Italiano

### ⚙️ Prerequisiti
Prima di iniziare, assicurati di avere a disposizione:
1. **Emulatore BizHawk & ROM di RogueMON**:
   * Fai riferimento alla [Guida Video Italiana di RogueMON creata da SevenSaske](https://www.youtube.com/watch?v=4rUprb1IhLg) per configurare emulatore, tracker e file di gioco.
2. **Streamer.bot**:
   * Scarica l'ultima versione di Streamer.bot dal [sito ufficiale](https://streamer.bot/).

---

### 🛠️ Installazione Passo dopo Passo

#### Passo 1: Configurazione Connessione Twitch su Streamer.bot
1. Avvia **Streamer.bot** e collega i tuoi account Broadcaster e Bot di Twitch.
2. Fai riferimento alla [Guida ufficiale di configurazione Twitch di Streamer.bot](https://docs.streamer.bot/get-started/setup#twitch-setup) se necessiti di aiuto per associare l'account.

#### Passo 2: Collegamento tra Ironmon-Tracker e Streamer.bot
1. Avvia RogueMON su BizHawk e apri lo script dell'Ironmon-Tracker.
2. Apri le Impostazioni del Tracker (icona dell'ingranaggio) -> seleziona la sezione **Streaming** -> clicca su **Stream Connect**.
3. Sotto la voce **Status**, clicca su **Connection Folder** e seleziona la cartella **`data`** che si trova dentro i file estratti di Streamer.bot (es. `C:\Streamer.bot\data\`).
4. Clicca su **Import Code** nel tracker.
5. In Streamer.bot, clicca su **Import** (menu in alto a sinistra), incolla il codice copiato, seleziona tutte le azioni importate nel gruppo `Tracker Integration` e clicca su **Import**.
6. **Importante**: Riavvia completamente **Streamer.bot** per assicurarti che carichi le nuove azioni e impostazioni di connessione.
7. Clicca sul pulsante **Connect** all'interno della schermata Stream Connect del tracker.
   * *Risoluzione Problemi*: Se lo stato non diventa `Online. Connection established`, chiudi lo script Lua del tracker su BizHawk, riavvialo e torna in **Streaming** -> **Stream Connect** per visualizzarlo connesso.

#### Passo 3: Configurare Azioni e Trigger su Streamer.bot
1. Seleziona la scheda **Actions** in Streamer.bot.
2. Sotto il gruppo di azioni `Tracker Integration`, seleziona l'azione **`RogueMON Streamer Event`**.
3. Nel pannello in basso a destra (**Sub-Actions**), configura le due sub-action:
   * **Set Argument**:
     * Fai clic destro nel pannello e seleziona **Add -> Core -> Arguments -> Set Argument**.
     * Imposta **Variable Name** su `trackerNetworkPath` (senza i simboli `%`).
     * Imposta **Value** con il percorso assoluto della cartella `data` del tuo Streamer.bot (es. `C:\Streamer.bot\data\`). **Importante**: Assicurati che termini con il backslash finale `\`.
   * **Execute C# Code**:
     * Fai clic destro nel pannello e seleziona **Add -> Core -> C# -> Execute C# Code**.
     * Fai doppio clic sulla sub-action appena creata per aprire l'editor C#.
     * Copia il codice dello script C# (riportato allo Step 3 della sezione in inglese) e incollalo nell'editor.
     * **Importante**: All'interno del codice C#, individua la riga del percorso predefinito (cerca `YOUR_STREAMERBOT_PATH`):
       `: @"C:\YOUR_STREAMERBOT_PATH\data\";`
       Sostituisci `"C:\YOUR_STREAMERBOT_PATH\data\"` con il percorso assoluto corretto della cartella `data` di Streamer.bot (lo stesso percorso che hai configurato nella sub-action *Set Argument*).
     * Clicca su **Compile** in fondo alla finestra (verifica che non ci sono errori in **Compiling Log** e che esca **Compiled successfully**) e premi **Save and Compile**.
4. Nel pannello in alto a destra (**Triggers**), associa i tuoi eventi di Twitch:
   * **Trigger per gli Abbonamenti (Subs)**: Fai clic destro -> **Twitch** -> **Subscriptions** -> Aggiungi **Subscription**, **Re-Subscription**, **Gift Subscription** e **Gift Bomb**.
   * **Trigger per i Punti Canale (Channel Points)**: Fai clic destro -> **Twitch** -> **Channel Reward** -> **Reward Redemption** -> Seleziona il riscatto punti canale creato su Twitch.
> [!IMPORTANT]
> **Requisito del Titolo dei Reward per i Punti Canale**: Il titolo del riscatto creato sul pannello Twitch del creator **DEVE** contenere il nome esatto dell'evento che desideri attivare (case-insensitive, ad esempio "Roguemon - Let's Dance" o "RogueMON - Restore HP"). In caso contrario, l'estensione non riconoscerà l'evento e non si attiverà.

#### Passo 4: Installare e Abilitare l'Estensione RogueMon Streamer
1. Estrai il file zip direttamente nella cartella `extensions` della directory di installazione del tuo Ironmon-Tracker.
2. Nel tracker, apri le Impostazioni (ingranaggio) -> seleziona **Extensions** -> scheda **General**.
3. Clicca su **Install a new extension**, naviga nella cartella delle estensioni, seleziona `roguemon-streamer-extension` e installala.

#### Passo 5: Opzioni, Test e Risoluzione dei Problemi
1. Apri la scheda delle opzioni dell'estensione RogueMon Streamer per configurare i pool da ascoltare: **Twitch Subs soltanto**, **Punti Canale soltanto**, o entrambi.
2. Se desideri testare gli eventi o simulare riscatti, utilizza la schermata di test dedicata all'interno delle opzioni dell'estensione.
3. Puoi visualizzare statistiche e grafiche per tenere traccia delle durate rimanenti in turni, configurare il conteggio sub o i traguardi delle milestone.
4. **Risoluzione Problemi**: Se l'estensione si comporta in modo anomalo o vuoi svuotare la coda delle richieste, clicca sul pulsante **Reset**. Questo cancellerà istantaneamente tutti gli eventi in coda e resetterà tutte le variabili della run a 0.