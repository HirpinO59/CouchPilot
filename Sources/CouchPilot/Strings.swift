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

    // Per i testi che citano più sigle del pad: gli indici posizionali (%1$@,
    // %2$@…) tengono l'ordine anche dove la traduzione lo cambia.
    static func t(_ key: String, _ arguments: [String]) -> String {
        String(format: t(key), arguments: arguments)
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
        // %@ è il grilletto del pad collegato: RT/LT su Xbox, R2/L2 su PlayStation.
        "set.precision": ["it": "Precisione %@", "en": "%@ precision",
                          "es": "Precisión %@", "zh": "%@ 精确模式"],
        "set.boost": ["it": "Turbo %@", "en": "%@ boost", "es": "Turbo %@", "zh": "%@ 加速"],

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
        "menu.keybinds": ["it": "Assegnazione tasti", "en": "Keybinds",
                          "es": "Asignación de botones", "zh": "按键设置"],
        // %@ è la versione installata: la pagina che si apre mostra l'ultima.
        "menu.updates": ["it": "Controlla aggiornamenti (%@)", "en": "Check for updates (%@)",
                         "es": "Buscar actualizaciones (%@)", "zh": "检查更新 (%@)"],
        "keybinds.save": ["it": "Salva", "en": "Save", "es": "Guardar", "zh": "保存"],
        "keybinds.reset": ["it": "Ripristina", "en": "Reset", "es": "Restablecer", "zh": "恢复默认"],
        "keybinds.close": ["it": "Chiudi", "en": "Close", "es": "Cerrar", "zh": "关闭"],
        "pad.leftStick": ["it": "Analogico SX · movimento", "en": "Left stick · movement",
                          "es": "Stick izquierdo · movimiento", "zh": "左摇杆 · 移动"],
        "pad.rightStick": ["it": "Analogico DX · movimento", "en": "Right stick · movement",
                           "es": "Stick derecho · movimiento", "zh": "右摇杆 · 移动"],
        "stick.cursor": ["it": "Muove il cursore", "en": "Moves the cursor",
                         "es": "Mueve el cursor", "zh": "移动光标"],
        "stick.scroll": ["it": "Scorre le pagine", "en": "Scrolls",
                         "es": "Desplaza la página", "zh": "滚动页面"],
        "stick.off": ["it": "Niente", "en": "Nothing", "es": "Nada", "zh": "无"],
        "key.space": ["it": "Spazio", "en": "Space", "es": "Espacio", "zh": "空格"],
        "bind.app": ["it": "Apri un'applicazione…", "en": "Open an app…",
                     "es": "Abrir una app…", "zh": "打开某个 App…"],
        "bind.appPanel": ["it": "Scegli l'applicazione da aprire con questo tasto",
                          "en": "Choose the app this button should open",
                          "es": "Elige la app que abrirá este botón",
                          "zh": "选择此按键要打开的 App"],
        "bind.appChoose": ["it": "Assegna", "en": "Assign", "es": "Asignar", "zh": "指定"],
        "capture.menu": ["it": "Registra input…", "en": "Record input…",
                         "es": "Grabar entrada…", "zh": "录制输入…"],
        "capture.title": ["it": "Premi cosa deve fare %@", "en": "Press what %@ should do",
                          "es": "Pulsa lo que debe hacer %@", "zh": "请按下 %@ 要执行的操作"],
        "capture.body": ["it": "Un tasto o una combinazione sulla tastiera, oppure clicca qui col pulsante del mouse che vuoi assegnare.",
                         "en": "A key or key combination, or click here with the mouse button you want to assign.",
                         "es": "Una tecla o combinación, o haz clic aquí con el botón del ratón que quieras asignar.",
                         "zh": "按下按键或组合键，或用想要指定的鼠标按键点击此处。"],
        "capture.hint": ["it": "esc annulla · ⌫ lascia il tasto senza azione",
                         "en": "esc cancels · ⌫ leaves the button unassigned",
                         "es": "esc cancela · ⌫ deja el botón sin acción",
                         "zh": "esc 取消 · ⌫ 清除该按键"],
        // Intestazione dell'assegnazione tasti: i comandi che non si cambiano.
        // Tutte le sigle vengono dal pad collegato: %1$@ e %2$@ sono i due tasti
        // centrali (View/Menu su Xbox, Create/Options su DualSense), %3$@ e %4$@
        // i grilletti sinistro e destro (LT/RT su Xbox, L2/R2 su PlayStation).
        "config.header": ["it": "%4$@ tenuto — precisione: cursore e scorrimento rallentano  ·  %3$@ tenuto — turbo: velocità doppia\n%2$@ da solo — apre il menu di CouchPilot  ·  %1$@ e %2$@ tenuti 2 secondi — attivazione/disattivazione",
                          "en": "Hold %4$@ — precision: cursor and scrolling slow down  ·  Hold %3$@ — turbo: double speed\n%2$@ alone — opens the CouchPilot menu  ·  %1$@ and %2$@ held 2 seconds — on/off",
                          "es": "%4$@ mantenido — precisión: cursor y desplazamiento más lentos  ·  %3$@ mantenido — turbo: velocidad doble\n%2$@ solo — abre el menú de CouchPilot  ·  %1$@ y %2$@ mantenidos 2 segundos — activación/desactivación",
                          "zh": "按住 %4$@——精确：光标和滚动变慢  ·  按住 %3$@——加速：速度翻倍\n单独按 %2$@——打开 CouchPilot 菜单  ·  按住 %1$@ 和 %2$@ 2 秒——启用/停用"],
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


        "welcome.next": ["it": "Avanti", "en": "Next", "es": "Siguiente", "zh": "下一步"],
        "welcome.done": ["it": "Iniziamo", "en": "Get started", "es": "Empezar", "zh": "开始使用"],
        "welcome.1.title": ["it": "Benvenuto in CouchPilot",
                            "en": "Welcome to CouchPilot",
                            "es": "Bienvenido a CouchPilot",
                            "zh": "欢迎使用 CouchPilot"],
        "welcome.1.body": ["it": "CouchPilot trasforma il controller in un telecomando per il Mac: cursore, click, scorrimento, volume e media senza alzarti dal divano.\n\nIl feedback è la cosa più importante: se qualcosa non va o vuoi una funzione nuova, chiedila senza esitare dal pulsante qui sotto.\n\nIn arrivo con la 1.2 — i profili: impostazioni e tasti diversi per ogni app.\n\n— HirpinO",
                           "en": "CouchPilot turns your controller into a remote for your Mac: cursor, clicks, scrolling, volume and media without leaving the couch.\n\nFeedback is what matters most: if something's off or you want a new feature, don't hesitate — ask with the button below.\n\nComing in 1.2 — profiles: different settings and bindings for each app.\n\n— HirpinO",
                           "es": "CouchPilot convierte tu mando en un control remoto para el Mac: cursor, clics, desplazamiento, volumen y multimedia sin levantarte del sofá.\n\nLo más importante es tu opinión: si algo falla o quieres una función nueva, pídela sin dudar con el botón de abajo.\n\nPróximamente en la 1.2 — perfiles: ajustes y botones distintos para cada app.\n\n— HirpinO",
                           "zh": "CouchPilot 把你的手柄变成 Mac 的遥控器：光标、点击、滚动、音量和媒体控制，不用离开沙发。\n\n反馈是最重要的：如果有问题或想要新功能，请随时用下方按钮告诉我。\n\n1.2 版即将推出——配置文件：为每个 App 设置不同的按键和参数。\n\n— HirpinO"],

        "welcome.3.title": ["it": "Assegnazione tasti",
                            "en": "Keybinds",
                            "es": "Asignación de botones",
                            "zh": "按键设置"],
        "welcome.back": ["it": "Indietro", "en": "Back", "es": "Atrás", "zh": "上一步"],
        "welcome.ax.needed": ["it": "Manca un passaggio: concedi il permesso Accessibilità.",
                              "en": "One step left: grant the Accessibility permission.",
                              "es": "Falta un paso: concede el permiso de Accesibilidad.",
                              "zh": "还差一步：请授予“辅助功能”权限。"],
        "welcome.login": ["it": "Avvia CouchPilot al login", "en": "Launch CouchPilot at login",
                          "es": "Abrir CouchPilot al iniciar sesión", "zh": "登录时启动 CouchPilot"],
        "welcome.ax.ok": ["it": "✓ Permesso Accessibilità concesso: è tutto pronto.",
                          "en": "✓ Accessibility permission granted — you're all set.",
                          "es": "✓ Permiso de Accesibilidad concedido: todo listo.",
                          "zh": "✓ 已获得“辅助功能”权限，一切就绪。"],
        "welcome.feedback": ["it": "Invia feedback", "en": "Send feedback",
                             "es": "Enviar comentarios", "zh": "发送反馈"],
        "welcome.coffee": ["it": "Buy Me a Coffee", "en": "Buy Me a Coffee",
                           "es": "Buy Me a Coffee", "zh": "Buy Me a Coffee"],
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
