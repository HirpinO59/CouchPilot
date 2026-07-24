import Foundation

enum Language: String, CaseIterable {
    case auto, it, en, es, zh

    // Nome mostrato nel menu: ogni lingua nella propria lingua, come fa macOS.
    var title: String {
        switch self {
        case .auto: return L.t("lang.auto")
        case .it: return "Italiano"
        case .en: return "English"
        case .es: return "Español"
        case .zh: return "中文"
        }
    }
}

enum L {
    static var current: Language {
        get { Language(rawValue: UserDefaults.standard.string(forKey: "language") ?? "auto") ?? .auto }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "language") }
    }

    // Con "auto" si segue la lingua di sistema; se non è tra quelle tradotte,
    // si ripiega sull'inglese.
    static var resolved: Language {
        let choice = current
        guard choice == .auto else { return choice }
        for tag in Locale.preferredLanguages {
            let code = String(tag.prefix(2)).lowercased()
            if let match = Language(rawValue: code), match != .auto { return match }
        }
        return .en
    }

    static func t(_ key: String) -> String {
        guard let row = table[key] else { return key }
        return row[resolved.rawValue] ?? row["en"] ?? key
    }

    static func t(_ key: String, _ argument: String) -> String {
        String(format: t(key), argument)
    }

    // Ogni voce con le sue quattro traduzioni affiancate: si rivedono a colpo
    // d'occhio e non si perde il filo tra un blocco e l'altro.
    private static let table: [String: [String: String]] = [
        "status.noController": ["it": "Nessun controller", "en": "No controller",
                                "es": "Sin mando", "zh": "未连接手柄"],
        "status.controller": ["it": "Controller: %@", "en": "Controller: %@",
                              "es": "Mando: %@", "zh": "手柄：%@"],
        "status.connected": ["it": "connesso", "en": "connected",
                             "es": "conectado", "zh": "已连接"],
        "status.paused": ["it": "In pausa: %@", "en": "Paused: %@",
                          "es": "En pausa: %@", "zh": "已暂停：%@"],
        "status.gameSuffix": ["it": "%@ (gioco)", "en": "%@ (game)",
                              "es": "%@ (juego)", "zh": "%@（游戏）"],

        "menu.active": ["it": "Attivo", "en": "Active", "es": "Activo", "zh": "已启用"],
        "menu.calibrate": ["it": "Calibra stick", "en": "Calibrate sticks",
                           "es": "Calibrar sticks", "zh": "校准摇杆"],
        "menu.calibrating": ["it": "Calibrazione… (stick fermi)", "en": "Calibrating… (hold sticks still)",
                             "es": "Calibrando… (no muevas los sticks)", "zh": "校准中…（请勿触碰摇杆）"],
        "menu.settings": ["it": "Impostazioni", "en": "Settings", "es": "Ajustes", "zh": "设置"],
        "menu.language": ["it": "Lingua", "en": "Language", "es": "Idioma", "zh": "语言"],
        "lang.auto": ["it": "Automatica (sistema)", "en": "Automatic (system)",
                      "es": "Automático (sistema)", "zh": "自动（跟随系统）"],

        "set.cursorSpeed": ["it": "Velocità cursore", "en": "Cursor speed",
                            "es": "Velocidad del cursor", "zh": "光标速度"],
        "set.scrollSpeed": ["it": "Velocità scroll", "en": "Scroll speed",
                            "es": "Velocidad de desplazamiento", "zh": "滚动速度"],
        "set.deadzone": ["it": "Deadzone stick", "en": "Stick deadzone",
                         "es": "Zona muerta del stick", "zh": "摇杆死区"],
        "set.curve": ["it": "Curva di risposta", "en": "Response curve",
                      "es": "Curva de respuesta", "zh": "响应曲线"],
        "set.precision": ["it": "Precisione R2", "en": "R2 precision",
                          "es": "Precisión R2", "zh": "R2 精确模式"],
        "set.boost": ["it": "Turbo L2", "en": "L2 boost", "es": "Turbo L2", "zh": "L2 加速"],

        "val.slow": ["it": "Lenta", "en": "Slow", "es": "Lenta", "zh": "慢"],
        "val.normal": ["it": "Normale", "en": "Normal", "es": "Normal", "zh": "正常"],
        "val.fast": ["it": "Veloce", "en": "Fast", "es": "Rápida", "zh": "快"],
        "val.turbo": ["it": "Turbo", "en": "Turbo", "es": "Turbo", "zh": "极快"],
        "val.low": ["it": "Bassa", "en": "Low", "es": "Baja", "zh": "小"],
        "val.high": ["it": "Alta", "en": "High", "es": "Alta", "zh": "大"],
        "val.linear": ["it": "Lineare", "en": "Linear", "es": "Lineal", "zh": "线性"],
        "val.soft": ["it": "Morbida", "en": "Soft", "es": "Suave", "zh": "柔和"],
        "val.standard": ["it": "Standard", "en": "Standard", "es": "Estándar", "zh": "标准"],
        "val.progressive": ["it": "Molto progressiva", "en": "Very progressive",
                            "es": "Muy progresiva", "zh": "强渐进"],
        "val.eighth": ["it": "⅛ della velocità", "en": "⅛ speed", "es": "⅛ de velocidad", "zh": "1/8 速度"],
        "val.quarter": ["it": "¼ della velocità", "en": "¼ speed", "es": "¼ de velocidad", "zh": "1/4 速度"],
        "val.half": ["it": "½ della velocità", "en": "½ speed", "es": "½ de velocidad", "zh": "1/2 速度"],
        "val.x15": ["it": "×1,5", "en": "×1.5", "es": "×1,5", "zh": "×1.5"],
        "val.x2": ["it": "×2", "en": "×2", "es": "×2", "zh": "×2"],
        "val.x3": ["it": "×3", "en": "×3", "es": "×3", "zh": "×3"],

        "menu.buttons": ["it": "Pulsanti", "en": "Buttons", "es": "Botones", "zh": "按键"],
        "menu.buttonL3": ["it": "L3 (pressione stick sx)", "en": "L3 (left stick press)",
                          "es": "L3 (pulsar stick izq.)", "zh": "L3（按下左摇杆）"],
        "menu.buttonR3": ["it": "R3 (pressione stick dx)", "en": "R3 (right stick press)",
                          "es": "R3 (pulsar stick der.)", "zh": "R3（按下右摇杆）"],
        "menu.dpadUp": ["it": "Croce ↑", "en": "D-pad ↑", "es": "Cruceta ↑", "zh": "方向键 ↑"],
        "menu.dpadDown": ["it": "Croce ↓", "en": "D-pad ↓", "es": "Cruceta ↓", "zh": "方向键 ↓"],
        "menu.dpadLeft": ["it": "Croce ←", "en": "D-pad ←", "es": "Cruceta ←", "zh": "方向键 ←"],
        "menu.dpadRight": ["it": "Croce →", "en": "D-pad →", "es": "Cruceta →", "zh": "方向键 →"],
        "menu.excluded": ["it": "Disattiva nelle app", "en": "Disable in apps",
                          "es": "Desactivar en apps", "zh": "在这些 App 中停用"],
        "menu.noExcluded": ["it": "Nessuna app esclusa", "en": "No apps excluded",
                            "es": "Ninguna app excluida", "zh": "尚未排除任何 App"],
        "menu.addApp": ["it": "Aggiungi app…", "en": "Add app…", "es": "Añadir app…", "zh": "添加 App…"],
        "panel.title": ["it": "Scegli le app in cui disattivare CouchPilot",
                        "en": "Choose the apps where CouchPilot should pause",
                        "es": "Elige las apps donde CouchPilot debe pausarse",
                        "zh": "选择需要暂停 CouchPilot 的 App"],
        "panel.choose": ["it": "Aggiungi", "en": "Add", "es": "Añadir", "zh": "添加"],
        "menu.gamesPause": ["it": "Pausa automatica nei giochi", "en": "Auto-pause in games",
                            "es": "Pausa automática en juegos", "zh": "游戏中自动暂停"],
        "menu.reset": ["it": "Ripristina predefiniti", "en": "Reset to defaults",
                       "es": "Restablecer valores", "zh": "恢复默认设置"],
        "menu.login": ["it": "Avvia al login", "en": "Launch at login",
                       "es": "Abrir al iniciar sesión", "zh": "登录时启动"],
        "menu.accessibility": ["it": "Apri permessi Accessibilità…", "en": "Open Accessibility settings…",
                               "es": "Abrir permisos de Accesibilidad…", "zh": "打开“辅助功能”权限…"],
        "menu.quit": ["it": "Esci da CouchPilot", "en": "Quit CouchPilot",
                      "es": "Salir de CouchPilot", "zh": "退出 CouchPilot"],
        "menu.keybinds": ["it": "Configurazione tasti", "en": "Keybinds",
                          "es": "Configuración de botones", "zh": "按键设置"],
        "keybinds.save": ["it": "Salva", "en": "Save", "es": "Guardar", "zh": "保存"],
        "keybinds.reset": ["it": "Ripristina", "en": "Reset", "es": "Restablecer", "zh": "恢复默认"],
        "pad.fixedSticks": ["it": "Stick sinistro: cursore · Stick destro: scorrimento",
                            "en": "Left stick: cursor · Right stick: scroll",
                            "es": "Stick izquierdo: cursor · Stick derecho: desplazamiento",
                            "zh": "左摇杆：光标 · 右摇杆：滚动"],
        "pad.fixedTriggers": ["it": "R2: precisione · L2: turbo",
                              "en": "R2: precision · L2: turbo",
                              "es": "R2: precisión · L2: turbo",
                              "zh": "R2：精确 · L2：加速"],
        "pad.fixedToggle": ["it": "View + Menu: accendi/spegni (non modificabile)",
                            "en": "View + Menu: on/off (not editable)",
                            "es": "View + Menu: encender/apagar (no editable)",
                            "zh": "View + Menu：开关（不可修改）"],
        "action.leftClick": ["it": "Click sinistro", "en": "Left click",
                             "es": "Clic izquierdo", "zh": "左键点击"],
        "action.rightClick": ["it": "Click destro", "en": "Right click",
                              "es": "Clic derecho", "zh": "右键点击"],
        "action.spaceLeft": ["it": "Scrivania precedente", "en": "Previous Space",
                             "es": "Escritorio anterior", "zh": "上一个桌面"],
        "action.spaceRight": ["it": "Scrivania successiva", "en": "Next Space",
                              "es": "Escritorio siguiente", "zh": "下一个桌面"],
        "menu.feedback": ["it": "Invia un feedback", "en": "Send feedback",
                          "es": "Enviar comentarios", "zh": "发送反馈"],
        "menu.welcome": ["it": "Guida rapida", "en": "Quick guide",
                         "es": "Guía rápida", "zh": "快速指南"],

        "diagram.cursor": ["it": "Cursore", "en": "Cursor", "es": "Cursor", "zh": "光标"],
        "diagram.scroll": ["it": "Scorri", "en": "Scroll", "es": "Desplazar", "zh": "滚动"],
        "diagram.click": ["it": "Click", "en": "Click", "es": "Clic", "zh": "点击"],
        "diagram.rightClick": ["it": "Tasto destro", "en": "Right click", "es": "Clic derecho", "zh": "右键"],
        "diagram.volume": ["it": "Volume", "en": "Volume", "es": "Volumen", "zh": "音量"],
        "diagram.onoff": ["it": "Accendi / Spegni", "en": "On / Off", "es": "Encender / Apagar", "zh": "开 / 关"],

        "welcome.next": ["it": "Avanti", "en": "Next", "es": "Siguiente", "zh": "下一步"],
        "welcome.done": ["it": "Iniziamo", "en": "Get started", "es": "Empezar", "zh": "开始使用"],
        "welcome.1.title": ["it": "Benvenuto in CouchPilot",
                            "en": "Welcome to CouchPilot",
                            "es": "Bienvenido a CouchPilot",
                            "zh": "欢迎使用 CouchPilot"],
        "welcome.1.body": ["it": "CouchPilot trasforma il tuo controller in un telecomando per il Mac: muovi il cursore, clicchi, scorri le pagine e regoli il volume senza alzarti dal divano.\n\nÈ gratis e non raccoglie nessun dato. Se qualcosa non funziona o ti manca una funzione, scrivimelo dalla voce “Invia un feedback”: le segnalazioni sono il modo in cui l'app migliora.\n\n— HirpinO",
                           "en": "CouchPilot turns your controller into a remote for your Mac: move the pointer, click, scroll and change the volume without getting off the couch.\n\nIt's free and collects no data. If something breaks or a feature is missing, tell me through “Send feedback” — reports are how this app gets better.\n\n— HirpinO",
                           "es": "CouchPilot convierte tu mando en un control remoto para el Mac: mueve el puntero, haz clic, desplázate y ajusta el volumen sin levantarte del sofá.\n\nEs gratis y no recopila ningún dato. Si algo falla o echas en falta una función, escríbeme desde “Enviar comentarios”: los avisos son lo que hace mejorar la app.\n\n— HirpinO",
                           "zh": "CouchPilot 把你的手柄变成 Mac 的遥控器：不用离开沙发，就能移动光标、点击、滚动页面和调节音量。\n\n它完全免费，且不收集任何数据。如果出现问题或缺少某个功能，请通过“发送反馈”告诉我——正是这些反馈让这款 App 变得更好。\n\n— HirpinO"],

        "welcome.2.title": ["it": "Il comando da ricordare",
                            "en": "The one command to remember",
                            "es": "El comando que hay que recordar",
                            "zh": "务必记住的操作"],
        "welcome.2.body": ["it": "Premi insieme View e Menu — i due tasti piccoli al centro del pad, chiamati Select e Start su altri controller — e CouchPilot si ferma all'istante: il controller torna al gioco o all'app che stai usando.\n\nPer riattivarlo, tieni premuti gli stessi due tasti per due secondi. Spegnere è immediato, riaccendere richiede intenzione: così non si riaccende da solo mentre giochi.",
                           "en": "Press View and Menu together — the two small buttons in the middle of the pad, called Select and Start on other controllers — and CouchPilot stops instantly: the controller goes back to the game or app you're using.\n\nTo switch it back on, hold those same two buttons for two seconds. Turning it off is instant, turning it on takes intent — so it never wakes up on its own while you play.",
                           "es": "Pulsa View y Menu a la vez — los dos botones pequeños del centro del mando, llamados Select y Start en otros controladores — y CouchPilot se detiene al instante: el mando vuelve al juego o a la app que estés usando.\n\nPara reactivarlo, mantén esos mismos dos botones durante dos segundos. Apagarlo es inmediato; encenderlo requiere intención, así nunca se reactiva solo mientras juegas.",
                           "zh": "同时按下 View 和 Menu——手柄中间的两个小按键，在其他控制器上叫 Select 和 Start——CouchPilot 会立即停止工作，手柄随即交还给你正在使用的游戏或 App。\n\n要重新启用，请按住这两个键两秒。关闭是瞬时的，开启则需要刻意操作，这样在游戏时它绝不会自行唤醒。"],

        "welcome.3.title": ["it": "Configurazione tasti",
                            "en": "Keybinds",
                            "es": "Configuración de botones",
                            "zh": "按键设置"],
        "welcome.3.body": ["it": "Stick sinistro: muovi il cursore. A: clicca, tienilo premuto per trascinare. X: tasto destro. Stick destro: scorri le pagine. Y: play e pausa. Croce direzionale: volume e tracce.\n\nTutto il resto vive nell'icona del gamepad vicino all'orologio: non c'è icona nel Dock. Funziona con i controller Xbox, PlayStation, Switch Pro e con ogni pad riconosciuto da macOS.",
                           "en": "Left stick: move the pointer. A: click, hold to drag. X: right click. Right stick: scroll. Y: play and pause. D-pad: volume and tracks.\n\nEverything else lives under the controller icon near the clock — there is no Dock icon. Works with Xbox, PlayStation and Switch Pro controllers, and any pad macOS recognises.",
                           "es": "Stick izquierdo: mueve el puntero. A: clic, mantén para arrastrar. X: clic derecho. Stick derecho: desplaza. Y: reproducir y pausar. Cruceta: volumen y pistas.\n\nTodo lo demás está en el icono del mando junto al reloj: no hay icono en el Dock. Funciona con mandos de Xbox, PlayStation y Switch Pro, y con cualquier mando que macOS reconozca.",
                           "zh": "左摇杆：移动光标。A：点击，按住可拖拽。X：右键。右摇杆：滚动。Y：播放与暂停。方向键：音量与曲目。\n\n其余功能都在时钟旁的手柄图标里——没有程序坞图标。支持 Xbox、PlayStation、Switch Pro 手柄，以及 macOS 能识别的任何手柄。"],
        "feedback.issues": ["it": "Segnala un problema o un'idea…", "en": "Report an issue or idea…",
                            "es": "Informar de un problema o idea…", "zh": "报告问题或建议…"],
        "feedback.email": ["it": "Scrivi un'email…", "en": "Send an email…",
                           "es": "Enviar un correo…", "zh": "发送邮件…"],
        "feedback.what": ["it": "Cosa succede", "en": "What happens",
                          "es": "Qué ocurre", "zh": "发生了什么"],
        "feedback.expected": ["it": "Cosa mi aspettavo", "en": "What I expected",
                              "es": "Qué esperaba", "zh": "预期行为"],
        "feedback.steps": ["it": "Come riprodurlo", "en": "Steps to reproduce",
                           "es": "Cómo reproducirlo", "zh": "复现步骤"],

        "action.none": ["it": "Nessuna azione", "en": "No action", "es": "Ninguna acción", "zh": "无操作"],
        "action.middleClick": ["it": "Click centrale (rotellina)", "en": "Middle click (wheel)",
                               "es": "Clic central (rueda)", "zh": "中键点击（滚轮）"],
        "action.mute": ["it": "Muto", "en": "Mute", "es": "Silenciar", "zh": "静音"],
        "action.playPause": ["it": "Play/Pausa", "en": "Play/Pause",
                             "es": "Reproducir/Pausa", "zh": "播放/暂停"],
        "action.volumeUp": ["it": "Volume su", "en": "Volume up", "es": "Subir volumen", "zh": "音量 +"],
        "action.volumeDown": ["it": "Volume giù", "en": "Volume down", "es": "Bajar volumen", "zh": "音量 −"],
        "action.previousTrack": ["it": "Traccia precedente", "en": "Previous track",
                                 "es": "Pista anterior", "zh": "上一曲"],
        "action.nextTrack": ["it": "Traccia successiva", "en": "Next track",
                             "es": "Pista siguiente", "zh": "下一曲"],
        "action.brightnessUp": ["it": "Luminosità su", "en": "Brightness up",
                                "es": "Subir brillo", "zh": "亮度 +"],
        "action.brightnessDown": ["it": "Luminosità giù", "en": "Brightness down",
                                  "es": "Bajar brillo", "zh": "亮度 −"],
        "action.missionControl": ["it": "Mission Control", "en": "Mission Control",
                                  "es": "Mission Control", "zh": "调度中心"],
        "action.showDesktop": ["it": "Mostra Scrivania", "en": "Show Desktop",
                               "es": "Mostrar Escritorio", "zh": "显示桌面"],
        "action.screenshot": ["it": "Screenshot (selezione area)", "en": "Screenshot (select area)",
                              "es": "Captura (seleccionar área)", "zh": "截屏（选择区域）"],
    ]
}
