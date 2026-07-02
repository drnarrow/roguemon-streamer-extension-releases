# RogueMON Twitch Streamer Extension

## 🇬🇧 Overview / 🇮🇹 Descrizione Generale

### 🇬🇧 English
An interactive, feature-rich extension designed to turn your Twitch chat into an active participant in your **RogueMON** runs! By integrating Twitch subscriptions, gifted subs, and custom Channel Points redemptions directly into BizHawk, your viewers can trigger unexpected in-game events in real-time. Whether they choose to save your run with a timely blessing or derail it with a chaotic curse, the chat holds the power to shape your journey!

### 🇮🇹 Italiano
Un'estensione interattiva e ricca di funzionalità creata per rendere la chat di Twitch una partecipante attiva e dinamica nelle tue run di **RogueMON**! Integrando abbonamenti, sub regalate e riscatti dei Punti Canale direttamente su BizHawk, i tuoi spettatori possono scatenare eventi di gioco del tutto inaspettati in tempo reale. Che scelgano di salvarti la run con una benedizione provvidenziale o di sabotarla con una maledizione caotica, lo spettatore diventa parte attiva della sfida!

---

> [!WARNING]
> *   **🇬🇧 Leaderboard Notice**: Since this extension introduces external chat integration, the official RogueMON leaderboard is automatically disabled while this extension is active to prevent unfair advantages or ranking manipulation.
> *   **🇮🇹 Avviso Classifica**: Poiché questa estensione introduce aiuti esterni ed interazione attiva con la chat, la classifica ufficiale (leaderboard) di RogueMON viene automaticamente disattivata quando l'estensione è attiva per evitare vantaggi sleali o manipolazioni dei punteggi.

---

> [!IMPORTANT]
> ### 🇬🇧 Public Beta Notice
> This extension is currently in **Public Beta** and was developed entirely as a solo project.
> *   **Twitch Limitations**: Due to not holding Twitch Affiliate/Partner status, testing custom channel point redemptions or sub gifts in a live stream environment was not possible.
> *   **Expect Potential Bugs**: Some event execution edge cases or bugs may occur during play.
> *   **Help Me Test**: If you are a streamer or just want to help me test or provide feedback, please contact **DrNarrow** directly on Discord at **`@DrNarrow`**.
> 
> ---
> 
> ### 🇮🇹 Avviso Beta Pubblica
> Questa estensione è attualmente in **Beta Pubblica** ed è stata sviluppata interamente da una persona sola.
> *   **Limiti di Twitch**: A causa della mancanza dello stato di Affiliato/Partner di Twitch, non è stato possibile testare i riscatti dei punti canale o sub twitch in un vero ambiente live di streaming.
> *   **Possibili Bug**: Potrebbero verificarsi bug imprevisti durante l'esecuzione di alcuni eventi.
> *   **Aiutami nei Test**: Se sei uno streamer o vuoi semplicemente aiutarmi a testare o condividere suggerimenti o bug, contatta direttamente **DrNarrow** su Discord **`@DrNarrow`**.

---

## 🇬🇧 English Guide

### ⚙️ Prerequisites
Before getting started, ensure you have the following ready:
1. **BizHawk Emulator & RogueMON ROM**:
   * Refer to the official [RogueMON Setup Video Guide by Crozwords](https://www.youtube.com/watch?v=26D8A1NCgCU) to configure your emulator, tracker, and game files. Alternatively, visit the credits section at the bottom for the link to the official RogueMON Discord where you can find all necessary files.
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
1. Extract the `roguemon-streamer-extension_X.X.X.zip` file directly into the `extensions` folder of your Ironmon-Tracker installation directory.
2. In the tracker, open Settings (gear icon) -> click **Extensions** -> select **General** tab.
3. Click **Install a new extension**, navigate to your extensions folder, select `roguemon-streamer-extension`, and install it.

#### Step 5: Options, Testing, and Troubleshooting
1. Open the RogueMon Streamer extension's options tab to configure which pools to listen to: **Twitch Subs only**, **Channel Points only**, or both.
2. If you want to test events or run simulations, use the dedicated test screen within the extension settings.
3. You can also view statistics to track remaining turn durations, configure sub counts, or adjust milestones.
4. **Troubleshooting**: If the extension behaves unexpectedly or you need to clear the request queue, click the **Reset** button. This instantly clears all queued events and resets all active streamer run variables back to 0.

*Enjoy your interactive RogueMON run!*

---

## 🇮🇹 Guida in Italiano

### ⚙️ Prerequisiti
Prima di iniziare, assicurati di avere a disposizione:
1. **Emulatore BizHawk & ROM di RogueMON**:
   * Fai riferimento alla [Guida Video Italiana di RogueMON creata da SevenSaske](https://www.youtube.com/watch?v=4rUprb1IhLg) per configurare emulatore, tracker e file di gioco. In alternativa, visita la sezione dei crediti in fondo per accedere al Discord ufficiale del creatore, dove troverai tutti i file necessari.
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
     * Imposta **Variable Name** su `trackerNetworkPath`.
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
1. Estrai il file `roguemon-streamer-extension_3.0.0.zip` direttamente nella cartella `extensions` della directory di installazione del tuo Ironmon-Tracker.
2. Nel tracker, apri le Impostazioni (ingranaggio) -> seleziona **Extensions** -> scheda **General**.
3. Clicca su **Install a new extension**, naviga nella cartella delle estensioni, seleziona `roguemon-streamer-extension` e installala.

#### Passo 5: Opzioni, Test e Risoluzione dei Problemi
1. Apri la scheda delle opzioni dell'estensione RogueMon Streamer per configurare i pool da ascoltare: **Twitch Subs soltanto**, **Punti Canale soltanto**, o entrambi.
2. Se desideri testare gli eventi o simulare riscatti, utilizza la schermata di test dedicata all'interno delle opzioni dell'estensione.
3. Puoi visualizzare statistiche e grafiche per tenere traccia delle durate rimanenti in turni, configurare il conteggio sub o i traguardi delle milestone.
4. **Risoluzione Problemi**: Se l'estensione si comporta in modo anomalo o vuoi svuotare la coda delle richieste, clicca sul pulsante **Reset**. Questo cancellerà istantaneamente tutti gli eventi in coda e resetterà tutte le variabili della run a 0.

*Buon divertimento con la tua run interattiva di RogueMON!*

---

## 🎮 Events Catalog / Catalogo degli Eventi

🇬🇧 This section catalogs all positive, negative, and channel point events, followed by the lists of events contained in each Twitch sub and channel point pool.

🇮🇹 Questa sezione mostra la lista di tutti gli eventi esistenti seguita dal dettaglio di quali eventi possono attivarsi con i rispettivi Sub Gift o Punti Canale.

---

### 📋 List of Events / Elenco degli Eventi

#### 🟢 Positive Events / Eventi Positivi
*   **Restore HP**
    *   *EN*: Instantly heals your active Pokémon's HP back to full.
    *   *IT*: Cura istantaneamente tutti gli HP del Pokémon attivo.
*   **Restore PP**
    *   *EN*: Restores the PP of one random move (or all moves for Milestones) of your active Pokémon.
    *   *IT*: Ripristina i PP di una mossa casuale (o di tutte le mosse per le Milestone) del Pokémon attivo.
*   **Cure Status**
    *   *EN*: Fully cures any active status condition (poison, burn, sleep, paralysis, freeze).
    *   *IT*: Cura qualsiasi stato alterato (veleno, scottatura, sonno, paralisi, congelamento).
*   **Full Restore**
    *   *EN*: Fully restores HP, status, and PP, and immediately clears active negative streamer curses.
    *   *IT*: Ripristina completamente HP, PP e stato del Pokémon attivo, rimuovendo le maledizioni degli spettatori.
*   **Give Healing Item**
    *   *EN*: Gifts a healing item (potion, hyper potion, full restore, etc.) directly to your bag.
    *   *IT*: Regala uno strumento di cura (pozione, iperpozione, ecc.) in borsa.
*   **Give Status Item**
    *   *EN*: Gifts a status curing item (antidote, full heal, etc.) to your bag.
    *   *IT*: Regala uno strumento di cura dello stato (antidoto, cura totale, ecc.) in borsa.
*   **Give PP Item**
    *   *EN*: Gifts a PP restoring item (ether, elixir, max elixir, etc.) to your bag.
    *   *IT*: Regala uno strumento per ripristinare i PP (etere, elisir, ecc.) in borsa.
*   **Give Utility Item / Items**
    *   *EN*: Gifts a Rare Candy or utility item directly to your bag.
    *   *IT*: Regala una Caramella Rara o uno strumento di utilità in borsa.
*   **Stat Boost**
    *   *EN*: Grants a persistent +1 stage boost in a random stat for a set number of battles.
    *   *IT*: Aumenta una statistica casuale di +1 stadio per un numero definito di lotte.
*   **Power Boost**
    *   *EN*: Grants a +1 stage boost in your Pokémon's primary offensive stat (Atk/SpAtk) for 1 battle.
    *   *IT*: Aumenta la statistica offensiva primaria (Atk/AtkSp) di +1 stadio per 1 lotta.
*   **Speed Boost**
    *   *EN*: Grants a +1 stage boost in Speed for 1 battle.
    *   *IT*: Aumenta la Velocità di +1 stadio per 1 lotta.
*   **Powerhouse Boost**
    *   *EN*: Grants a +1 stage boost in both Speed and primary offensive stat for multiple battles.
    *   *IT*: Aumenta Velocità e statistica offensiva di +1 stadio per molteplici lotte.
*   **Omniboost**
    *   *EN*: Grants a +1 stage boost to all stats for 1 battle.
    *   *IT*: Aumenta tutte le statistiche del Pokémon attivo di +1 stadio per 1 lotta.
*   **PP Up**
    *   *EN*: Increases the maximum PP of one eligible move of your active Pokémon.
    *   *IT*: Aumenta i PP massimi di una mossa idonea del Pokémon attivo.
*   **No Guard Plus**
    *   *EN*: Grants your active Pokémon the No Guard effect (100% accuracy) for multiple battles.
    *   *IT*: Attiva l'effetto Nullodifesa (precisione 100%) sul tuo Pokémon per più lotte.
*   **Turbo Genetics**
    *   *EN*: Restricts evolution candidates of your Pokémon to the top 10 species with the highest BST.
    *   *IT*: Limita le possibili evoluzioni del tuo Pokémon alle top 10 con BST più alto.
*   **Evolution Power**
    *   *EN*: Gifts 1 Roguestone directly to your bag to evolve your Pokémon.
    *   *IT*: Regala 1 Pietra Roguestone in borsa per far evolvere il tuo Pokémon.
*   **Increase Healing Limit**
    *   *EN*: Increases the carrying limit of HP healing items in your bag.
    *   *IT*: Aumenta il limite massimo di strumenti di cura HP trasportabili.
*   **Increase Status Limit**
    *   *EN*: Increases the carrying limit of status-curing items in your bag.
    *   *IT*: Aumenta il limite massimo di strumenti cura stato trasportabili.
*   **Game Changer**
    *   *EN*: Grants +2 critical hit stage for multiple battles.
    *   *IT*: Attiva Messa a Fuoco (+2 stadi di brutto colpo) per molteplici lotte.
*   **Try Harder**
    *   *EN*: Makes your active Pokémon immune to stat drops for multiple battles.
    *   *IT*: Rende il tuo Pokémon attivo immune ai cali di statistica per molteplici lotte.
*   **Let's Dance**
    *   *EN*: Opens an interactive menu to permanently replace a chosen move with a random one, or choose the "Random" option to replace a random move with a damaging one.
    *   *IT*: Apre un menu a scelta per sostituire permanentemente una mossa a scelta con una casuale, o scegliere "Random" per sostituire una mossa casuale con una mossa offensiva.

#### 🔴 Negative Events / Eventi Negativi (Curses)
*   **Inflict Status**
    *   *EN*: Inflicts a random status condition (poison, burn, sleep, paralysis, freeze).
    *   *IT*: Infligge uno stato alterato casuale (avvelenamento, paralisi, scottatura, congelamento, sonno).
*   **Disable Move**
    *   *EN*: Disables one random move slot of your active Pokémon for a set number of battles/turns.
    *   *IT*: Inibisce l'uso di una delle mosse del tuo Pokémon attivo per un certo numero di lotte/turni.
*   **Empowered Disable**
    *   *EN*: Disables one of your Pokémon's moves for a massive 10 battles.
    *   *IT*: Inibisce l'uso di una delle tue mosse per ben 10 lotte consecutive.
*   **Power Debuff**
    *   *EN*: Inflicts a persistent -1 stage penalty in primary offensive stat for a set number of battles.
    *   *IT*: Penalizza la statistica offensiva primaria di -1 stadio per un certo numero di lotte.
*   **Speed Debuff**
    *   *EN*: Inflicts a persistent -1 stage penalty in Speed for a set number of battles.
    *   *IT*: Riduce la Velocità di -1 stadio per un certo numero di lotte.
*   **PP Cut**
    *   *EN*: Halves the current PP of one random move slot of your active Pokémon.
    *   *IT*: Dimezza i PP attuali di una mossa casuale del tuo Pokémon attivo.
*   **Stat Debuff**
    *   *EN*: Inflicts a persistent -1 stage penalty in a random stat for a set number of battles.
    *   *IT*: Riduce una statistica casuale di -1 stadio per un certo numero di lotte.
*   **Empowered Debuff**
    *   *EN*: Inflicts a persistent -1 stage penalty in a random stat for 10 battles.
    *   *IT*: Applica una penalità persistente di -1 a una statistica per 10 lotte.
*   **Temp Type Change**
    *   *EN*: Temporarily overrides your Pokémon's typing for 1 battle.
    *   *IT*: Sostituisce temporaneamente i tipi del tuo Pokémon per 1 lotta.
*   **Remove Healing Item**
    *   *EN*: Discards a small healing item from your bag.
    *   *IT*: Scarta uno strumento di cura minore dal tuo inventario.
*   **Remove Status Item**
    *   *EN*: Discards a status curing item from your bag.
    *   *IT*: Rimuove uno strumento di cura dello stato dal tuo inventario.
*   **Remove Big Healing Item**
    *   *EN*: Discards major healing items (e.g., Full Restore, Max Potion) from your bag.
    *   *IT*: Rimuove uno strumento di cura primario (es. Ricarica Totale) dalla borsa.
*   **Remove Utility Item / Items**
    *   *EN*: Discards valuable utility items (Rare Candy, Max Elixirs, PP Max) from your bag.
    *   *IT*: Scarta strumenti di utilità preziosi (Caramelle Rare, PP Max, Max Elisir) dalla borsa.
*   **Overwhelmed**
    *   *EN*: Reduces your Pokémon's HP by a percentage and triggers a persistent extra PP usage penalty (same as Pressure ability effect).
    *   *IT*: Riduce gli HP del Pokémon di una percentuale e applica una penalità sul consumo extra di PP (uguale all'effetto dell'abilità Pressione).
*   **PP Deplete**
    *   *EN*: Reduces the PP of all moves of your active Pokémon by a percentage (20%, 50%, or 100%).
    *   *IT*: Riduce i PP di tutte le mosse del Pokémon attivo (del 20%, 50% o 100%).
*   **Permanent Type Change**
    *   *EN*: Permanently alters your Pokémon's typing to a randomized (detrimental) combination.
    *   *IT*: Cambia permanentemente il tipo del Pokémon in uno svantaggioso.
*   **Permanent Nature Change**
    *   *EN*: Permanently alters your Pokémon's nature to a random (detrimental) nature.
    *   *IT*: Cambia permanentemente la natura del Pokémon attivo in una svantaggiosa.
*   **Permanent Ability Change**
    *   *EN*: Permanently alters your Pokémon's ability to a random (detrimental) ability.
    *   *IT*: Cambia permanentemente l'abilità del Pokémon attivo in una svantaggiosa.
*   **Out of Control**
    *   *EN*: Your Pokémon doesn't obey you anymore and may attack with a random move of his moveset or stand still for multiple turns.
    *   *IT*: Il tuo Pokémon non ti obbedisce più e può attaccare con una mossa a caso di quelle conosciute o stare fermo per più turni.
*   **Omnimalus**
    *   *EN*: Lowers all stats of your active Pokémon by -1 stage for multiple battles.
    *   *IT*: Abbassa tutte le statistiche del Pokémon attivo di -1 stadio per più lotte.
*   **No Guard Minus**
    *   *EN*: Grants your opponent the No Guard effect (100% accuracy) for multiple battles.
    *   *IT*: Attiva l'effetto Nullodifesa (precisione 100%) sui Pokémon avversari per più lotte.
*   **Mystification**
    *   *EN*: Activates Trick Room (slower Pokémon move first) for multiple battles.
    *   *IT*: Attiva l'effetto Distortozona in battaglia per più lotte.

#### 🔵 Channel Points Exclusive Random Events / Riscatti Casuali Esclusivi
*   **Type Change**
    *   *EN*: Changes the typing of your Pokémon permanently to a completely random single or dual type.
    *   *IT*: Sostituisce il tipo del tuo Pokémon con uno singolo o doppio completamente casuale.
*   **Nature Change**
    *   *EN*: Changes the nature of your Pokémon permanently to a completely random one.
    *   *IT*: Sostituisce la natura del tuo Pokémon con una completamente casuale.
*   **Ability Change**
    *   *EN*: Changes the ability of your Pokémon permanently to a completely random one.
    *   *IT*: Sostituisce l'abilità del tuo Pokémon con una completamente casuale.

---

### 🎁 Event Pools / Composizione dei Pool

This section defines which events are grouped in each pool.

#### 1. Cumulative Sub Pools / Pool Sub Cumulative
*   **🟢 Positive Pool (Helps)**:
    *   Restore PP, Cure Status, Restore HP, Give Healing Item, Give Status Item, Give PP Item, Stat Boost, Power Boost, Speed Boost, PP Up, Let's Dance.
*   **🔴 Negative Pool (Curses)**:
    *   Inflict Status, Disable Move, Power Debuff, Speed Debuff, PP Cut, Stat Debuff, Temp Type Change, Remove Healing Item, Remove Status Item, Overwhelmed, Let's Dance.

#### 2. Milestone Sub Pools / Pool delle Sub Gift (5, 10, 20, 50)
*   **🟢 Positive Pool (Milestone Rewards)**:
    *   Restore PP, Full Restore, Give Healing Item, Give Utility Item, Give PP Item, Stat Boost, Permanent Type Change, Permanent Nature Change, Permanent Ability Change, Powerhouse Boost, No Guard Plus, Turbo Genetics, Let's Dance, Game Changer, Try Harder.
*   **🔴 Negative Pool (Milestone Curses)**:
    *   Overwhelmed, Empowered Disable, Empowered Debuff, PP Deplete, Permanent Type Change, Permanent Nature Change, Permanent Ability Change, Remove Big Healing Item, Remove Utility Item, Out of Control, Omnimalus, No Guard Minus, Mystification, Let's Dance.

#### 3. Twitch Channel Points Rewards / Riscatti dei Punti Canale
*   **🟢 Positive Options**:
    *   Restore HP, Restore PP, Cure Status, Full Restore, Give Healing Item, Give Status Item, Give PP Item, Give Utility Item, Stat Boost, Power Boost, Speed Boost, PP Up, No Guard Plus, Powerhouse Boost, Turbo Genetics, Omniboost, Evolution Power, Increase Healing Limit, Increase Status Limit, Game Changer, Try Harder, Let's Dance.
*   **🔴 Negative Options**:
    *   Inflict Status, Disable Move, Empowered Disable, Power Debuff, Speed Debuff, PP Cut, Temp Type Change, Remove Healing Item, Remove Status Item, Remove Big Healing Item, Remove Utility Item, Stat Debuff, Empowered Debuff, PP Deplete, Mystification, Omnimalus, No Guard Minus, Out of Control, Overwhelmed, Let's Dance.
*   **🔵 Exclusive Random Options**:
    *   Type Change, Nature Change, Ability Change.

---

## 🏆 Credits / Crediti

### 🇬🇧 English
*   **Extension Creator**: Developed by **DrNarrow** (Discord: `@DrNarrow`). If you need support, want to report bugs, or have suggestions, feel free to reach out directly on Discord!
*   **RogueMON Challenge**: This streamer extension is designed to run alongside **RogueMON**, the incredibly polished Roguelike Pokémon Challenge created by **Crozwords**. 
*   **Official Website**: Visit [roguemon.gg](https://www.roguemon.gg/) to track runs and view leaderboards.
*   **Official Discord**: Join the community for setup resources, guides, and updates: [https://discord.gg/C88N88yfCP](https://discord.gg/C88N88yfCP).

### 🇮🇹 Italiano
*   **Creatore dell'Estensione**: Sviluppata da **DrNarrow** (Discord: `@DrNarrow`). Se hai bisogno di supporto, vuoi segnalare bug o proporre suggerimenti, sentiti libero di scrivermi direttamente su Discord!
*   **Sfida RogueMON**: Questa estensione per streamer è progettata per essere utilizzata insieme a **RogueMON**, l'incredibile sfida Pokémon in stile Roguelike creata da **Crozwords**.
*   **Sito Web Ufficiale**: Visita [roguemon.gg](https://www.roguemon.gg/) per seguire le run e vedere le classifiche globali.
*   **Discord Ufficiale**: Entra nella community per trovare le risorse d'installazione, guide e novità: [https://discord.gg/C88N88yfCP](https://discord.gg/C88N88yfCP).
