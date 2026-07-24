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
        "menu.feedback": ["it": "Invia un feedback", "en": "Send feedback",
                          "es": "Enviar comentarios", "zh": "发送反馈"],
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
