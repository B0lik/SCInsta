#import "TweakSettings.h"
#import "../Features/General/SCISubscriptionManager.h"

@implementation SCITweakSettings

// MARK: - Sections

///
/// This returns an array of sections, with each section consisting of a dictionary
///
/// `"title"`: The section title (leave blank for no title)
///
/// `"rows"`: An array of **SCISetting** classes, potentially containing a "navigationCellWithTitle" initializer to allow for nested setting pages.
///
/// `"footer`: The section footer (leave blank for no footer)

+ (NSArray *)sections {
    return @[
        @{
            @"header": @"",
            @"rows": @[
                [SCISetting linkCellWithTitle:@"Поддержать разработчика" subtitle:@"Поддержать разработку SCInsta" icon:[SCISymbol symbolWithName:@"heart.circle.fill" color:[UIColor systemPinkColor] size:20.0] url:@"https://ko-fi.com/SoCuul"]
            ]
        },
        @{
            @"header": @"",
            @"rows": @[
                [SCISetting navigationCellWithTitle:@"VPN / подписка"
                                           subtitle:[SCISubscriptionManager statusText]
                                               icon:[SCISymbol symbolWithName:@"shield.lefthalf.filled"]
                                        navSections:@[@{
                                            @"header": @"VPN только для Instagram",
                                            @"footer": @"Вставьте обычную ссылку VPN-подписки. Instagram поднимет локальный sing-box-туннель внутри приложения; системный VPN не включается и другие приложения не затрагиваются.",
                                            @"rows": @[
                                                [SCISetting buttonCellWithTitle:@"Импортировать подписку"
                                                                       subtitle:@"VLESS, VMess, Trojan, Shadowsocks или sing-box JSON"
                                                                           icon:[SCISymbol symbolWithName:@"link"]
                                                                         action:^(void) { [SCISubscriptionManager presentSubscriptionUI]; }],
                                                [SCISetting buttonCellWithTitle:@"Проверить VPN"
                                                                       subtitle:@"Показывает внешний IP через встроенный туннель"
                                                                           icon:[SCISymbol symbolWithName:@"network.badge.shield.half.filled"]
                                                                         action:^(void) { [SCISubscriptionManager presentConnectionTest]; }],
                                                [SCISetting staticCellWithTitle:@"Текущий статус"
                                                                      subtitle:[SCISubscriptionManager statusText]
                                                                          icon:[SCISymbol symbolWithName:@"checkmark.shield"]]
                                            ]
                                        }]
                ],
                [SCISetting navigationCellWithTitle:@"Основные"
                                           subtitle:@""
                                               icon:[SCISymbol symbolWithName:@"gear"]
                                        navSections:@[@{
                                            @"header": @"",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Скрыть рекламу" subtitle:@"Удаляет рекламу из Instagram" defaultsKey:@"hide_ads"],
                                                [SCISetting switchCellWithTitle:@"Скрыть Meta AI" subtitle:@"Скрывает кнопки и функции Meta AI" defaultsKey:@"hide_meta_ai"],
                                                [SCISetting switchCellWithTitle:@"Копировать описание" subtitle:@"Копирование текста описания долгим нажатием" defaultsKey:@"copy_description"],
                                                [SCISetting switchCellWithTitle:@"Не сохранять историю поиска" subtitle:@"Поиск больше не будет сохранять недавние запросы" defaultsKey:@"no_recent_searches"],
                                                [SCISetting switchCellWithTitle:@"Расширенная палитра цветов" subtitle:@"Удерживайте пипетку в Stories для точной настройки цвета" defaultsKey:@"detailed_color_picker"],
                                                [SCISetting switchCellWithTitle:@"Включить Liquid Glass для кнопок" subtitle:@"Включает экспериментальный эффект Liquid Glass для кнопок" defaultsKey:@"liquid_glass_buttons" requiresRestart:YES],
                                                [SCISetting switchCellWithTitle:@"Включить Liquid Glass для поверхностей" subtitle:@"Включает Liquid Glass для меню и других элементов" defaultsKey:@"liquid_glass_surfaces" requiresRestart:YES],
                                                [SCISetting switchCellWithTitle:@"Включить подростковые иконки приложения" subtitle:@"После включения удерживайте логотип Instagram для смены иконки" defaultsKey:@"teen_app_icons" requiresRestart:YES]
                                            ]
                                        },
                                        @{
                                            @"header": @"Заметки",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Скрыть панель заметок" subtitle:@"Скрывает панель заметок в Direct" defaultsKey:@"hide_notes_tray"],
                                                [SCISetting switchCellWithTitle:@"Скрыть карту друзей" subtitle:@"Скрывает значок карты друзей в панели заметок" defaultsKey:@"hide_friends_map"],
                                                [SCISetting switchCellWithTitle:@"Темы заметок" subtitle:@"Включает выбор темы заметок" defaultsKey:@"enable_notes_customization"],
                                                [SCISetting switchCellWithTitle:@"Свои темы заметок" subtitle:@"Позволяет менять эмодзи, фон и цвет текста" defaultsKey:@"custom_note_themes"],
                                            ]
                                        },
                                        @{
                                            @"header": @"Фокус / отвлекающий контент",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Без рекомендаций пользователей" subtitle:@"Скрывает рекомендации аккаунтов вне ленты" defaultsKey:@"no_suggested_users"],
                                                [SCISetting switchCellWithTitle:@"Без рекомендованных чатов" subtitle:@"Скрывает рекомендованные каналы в Direct" defaultsKey:@"no_suggested_chats"],
                                                [SCISetting switchCellWithTitle:@"Скрыть сетку рекомендаций" subtitle:@"Скрывает рекомендованные публикации на вкладке поиска" defaultsKey:@"hide_explore_grid"],
                                                [SCISetting switchCellWithTitle:@"Скрыть популярные запросы" subtitle:@"Скрывает популярные запросы под строкой поиска" defaultsKey:@"hide_trending_searches"],
                                            ]
                                        }]
                ],
                [SCISetting navigationCellWithTitle:@"Лента"
                                           subtitle:@""
                                               icon:[SCISymbol symbolWithName:@"rectangle.stack"]
                                        navSections:@[@{
                                            @"header": @"",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Скрыть Stories" subtitle:@"Скрывает панель Stories сверху и в ленте" defaultsKey:@"hide_stories_tray"],
                                                [SCISetting switchCellWithTitle:@"Скрыть всю ленту" subtitle:@"Удаляет весь контент из домашней ленты" defaultsKey:@"hide_entire_feed"],
                                                [SCISetting switchCellWithTitle:@"Без рекомендованных публикаций" subtitle:@"Убирает рекомендованные публикации из ленты" defaultsKey:@"no_suggested_post"],
                                                [SCISetting switchCellWithTitle:@"Без рекомендаций «для вас»" subtitle:@"Скрывает предложенные аккаунты" defaultsKey:@"no_suggested_account"],
                                                [SCISetting switchCellWithTitle:@"Без рекомендованных Reels" subtitle:@"Убирает рекомендованные Reels" defaultsKey:@"no_suggested_reels"],
                                                [SCISetting switchCellWithTitle:@"Без рекомендаций Threads" subtitle:@"Убирает рекомендованные публикации Threads" defaultsKey:@"no_suggested_threads"],
                                                [SCISetting switchCellWithTitle:@"Отключить автозапуск видео" subtitle:@"Не запускает видео в ленте автоматически" defaultsKey:@"disable_feed_autoplay"]
                                            ]
                                        }]
                ],
                [SCISetting navigationCellWithTitle:@"Reels"
                                           subtitle:@""
                                               icon:[SCISymbol symbolWithName:@"film.stack"]
                                        navSections:@[@{
                                            @"header": @"",
                                            @"rows": @[
                                                [SCISetting menuCellWithTitle:@"Действие по нажатию" subtitle:@"Выберите действие при нажатии на Reel" menu:[self menus][@"reels_tap_control"]],
                                                [SCISetting switchCellWithTitle:@"Всегда показывать полосу прогресса" subtitle:@"Всегда показывает полосу прокрутки видео" defaultsKey:@"reels_show_scrubber"],
                                                [SCISetting switchCellWithTitle:@"Не включать звук Reels автоматически" subtitle:@"Не включает звук Reels автоматически при изменении громкости" defaultsKey:@"disable_auto_unmuting_reels" requiresRestart:YES],
                                                [SCISetting switchCellWithTitle:@"Подтверждать обновление Reels" subtitle:@"Показывает подтверждение перед обновлением Reels" defaultsKey:@"refresh_reel_confirm"],
                                            ]
                                        },
                                        @{
                                            @"header": @"Скрытие",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Скрыть верхнюю панель Reels" subtitle:@"Скрывает верхнюю панель при просмотре Reels" defaultsKey:@"hide_reels_header"],
                                                [SCISetting switchCellWithTitle:@"Скрыть кнопку Blend" subtitle:@"Скрывает кнопку Blend для Reels в Direct" defaultsKey:@"hide_reels_blend"]
                                            ]
                                        },
                                        @{
                                            @"header": @"Ограничения",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Запретить листание Reels" subtitle:@"Не позволяет свайпнуть к следующему Reel" defaultsKey:@"disable_scrolling_reels" requiresRestart:YES],
                                                [SCISetting switchCellWithTitle:@"Ограничить бесконечный скроллинг" subtitle:@"Ограничивает число доступных Reels и запрещает обновление бесконечной ленты" defaultsKey:@"prevent_doom_scrolling"],
                                                [SCISetting stepperCellWithTitle:@"Лимит Reels" subtitle:@"Загружать только %@ %@" defaultsKey:@"doom_scrolling_reel_count" min:1 max:100 step:1 label:@"reels" singularLabel:@"reel"]
                                            ]
                                        }]
                ],
                [SCISetting navigationCellWithTitle:@"Скачивание"
                                           subtitle:@""
                                               icon:[SCISymbol symbolWithName:@"tray.and.arrow.down"]
                                        navSections:@[@{
                                            @"header": @"",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Скачивать публикации" subtitle:@"Долгое нажатие пальцами скачивает публикацию" defaultsKey:@"dw_feed_posts"],
                                                [SCISetting switchCellWithTitle:@"Скачивать Reels" subtitle:@"Долгое нажатие на Reel скачивает его" defaultsKey:@"dw_reels"],
                                                [SCISetting switchCellWithTitle:@"Скачивать Stories" subtitle:@"Долгое нажатие во время просмотра Story скачивает её" defaultsKey:@"dw_story"],
                                                [SCISetting switchCellWithTitle:@"Сохранять фото профиля" subtitle:@"Откройте аватар в профиле и удерживайте для скачивания" defaultsKey:@"save_profile"]
                                            ]
                                        },
                                        @{
                                            @"header": @"Настройка жестов",
                                            @"rows": @[
                                                [SCISetting stepperCellWithTitle:@"Пальцев для долгого нажатия" subtitle:@"Скачивание: %@ %@" defaultsKey:@"dw_finger_count" min:1 max:5 step:1 label:@"fingers" singularLabel:@"finger"],
                                                [SCISetting stepperCellWithTitle:@"Время удержания" subtitle:@"Удерживать %@ %@" defaultsKey:@"dw_finger_duration" min:0 max:10 step:0.25 label:@"sec" singularLabel:@"sec"]
                                            ]
                                        }]
                ],
                [SCISetting navigationCellWithTitle:@"Stories и сообщения"
                                           subtitle:@""
                                               icon:[SCISymbol symbolWithName:@"rectangle.portrait.on.rectangle.portrait.angled"]
                                        navSections:@[@{
                                            @"header": @"Сообщения",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Сохранять удалённые сообщения" subtitle:@"Сохраняет удалённые сообщения в чатах" defaultsKey:@"keep_deleted_message"],
                                                [SCISetting switchCellWithTitle:@"Отмечать сообщения прочитанными вручную" subtitle:@"Добавляет кнопку ручной отметки сообщения как прочитанного" defaultsKey:@"remove_lastseen"],
                                                [SCISetting switchCellWithTitle:@"Скрыть статус набора текста" subtitle:@"Не показывает собеседнику, что вы печатаете" defaultsKey:@"disable_typing_status"],
                                            ]
                                        },
                                        @{
                                            @"header": @"Исчезающие сообщения и Stories",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Безлимитный повтор исчезающих сообщений" subtitle:@"Позволяет повторно смотреть исчезающие фото и видео" defaultsKey:@"unlimited_replay"],
                                                [SCISetting switchCellWithTitle:@"Убрать ограничение «один просмотр»" subtitle:@"Позволяет повторять и ставить на паузу сообщения «один просмотр»" defaultsKey:@"disable_view_once_limitations"],
                                                [SCISetting switchCellWithTitle:@"Отключить обнаружение скриншотов" subtitle:@"Убирает ограничения на скриншоты в Direct" defaultsKey:@"remove_screenshot_alert"],
                                                [SCISetting switchCellWithTitle:@"Не отправлять отметку просмотра Story" subtitle:@"Не сообщает другим о просмотре их Story" defaultsKey:@"no_seen_receipt"],
                                                [SCISetting switchCellWithTitle:@"Отключить создание Instants" subtitle:@"Скрывает создание и отправку Instants" defaultsKey:@"disable_instants_creation" requiresRestart:YES]
                                            ]
                                        }]
                ],
                [SCISetting navigationCellWithTitle:@"Навигация"
                                           subtitle:@""
                                               icon:[SCISymbol symbolWithName:@"hand.draw.fill"]
                                        navSections:@[@{
                                            @"header": @"",
                                            @"rows": @[
                                                [SCISetting menuCellWithTitle:@"Порядок иконок" subtitle:@"Порядок иконок в нижней панели" menu:[self menus][@"nav_icon_ordering"]],
                                                [SCISetting menuCellWithTitle:@"Свайп между вкладками" subtitle:@"Переключение вкладок свайпом" menu:[self menus][@"swipe_nav_tabs"]],
                                            ]
                                        },
                                        @{
                                            @"header": @"Скрытие вкладок",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Скрыть вкладку «Главная»" subtitle:@"Скрывает вкладку домашней ленты снизу" defaultsKey:@"hide_feed_tab" requiresRestart:YES],
                                                [SCISetting switchCellWithTitle:@"Скрыть вкладку поиска" subtitle:@"Скрывает вкладку поиска снизу" defaultsKey:@"hide_explore_tab" requiresRestart:YES],
                                                [SCISetting switchCellWithTitle:@"Скрыть вкладку Reels" subtitle:@"Скрывает вкладку Reels в нижней панели" defaultsKey:@"hide_reels_tab" requiresRestart:YES],
                                                [SCISetting switchCellWithTitle:@"Скрыть кнопку создания" subtitle:@"Скрывает кнопку создания в нижней панели" defaultsKey:@"hide_create_tab" requiresRestart:YES]
                                            ]
                                        }]
                ],
                [SCISetting navigationCellWithTitle:@"Подтверждение действий"
                                           subtitle:@""
                                               icon:[SCISymbol symbolWithName:@"checkmark"]
                                        navSections:@[@{
                                            @"header": @"",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Подтверждать лайк: публикации/Stories" subtitle:@"Просит подтверждение перед лайком публикации или Story" defaultsKey:@"like_confirm"],
                                                [SCISetting switchCellWithTitle:@"Подтверждать лайк: Reels" subtitle:@"Просит подтверждение перед лайком Reel" defaultsKey:@"like_confirm_reels"]
                                            ]
                                        },
                                        @{
                                            @"header": @"",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Подтверждать подписку" subtitle:@"Просит подтверждение перед подпиской на аккаунт" defaultsKey:@"follow_confirm"],
                                                [SCISetting switchCellWithTitle:@"Подтверждать репост" subtitle:@"Просит подтверждение перед репостом" defaultsKey:@"repost_confirm"],
                                                [SCISetting switchCellWithTitle:@"Подтверждать звонок" subtitle:@"Просит подтверждение перед аудио/видеозвонком" defaultsKey:@"call_confirm"],
                                                [SCISetting switchCellWithTitle:@"Подтверждать голосовые сообщения" subtitle:@"Просит подтверждение перед отправкой голосового сообщения" defaultsKey:@"voice_message_confirm"],
                                                [SCISetting switchCellWithTitle:@"Подтверждать запросы на подписку" subtitle:@"Просит подтверждение при принятии или отклонении запроса" defaultsKey:@"follow_request_confirm"],
                                                [SCISetting switchCellWithTitle:@"Подтверждать исчезающие сообщения" subtitle:@"Просит подтверждение перед включением исчезающих сообщений" defaultsKey:@"shh_mode_confirm"],
                                                [SCISetting switchCellWithTitle:@"Подтверждать комментарий" subtitle:@"Просит подтверждение перед публикацией комментария" defaultsKey:@"post_comment_confirm"],
                                                [SCISetting switchCellWithTitle:@"Подтверждать смену темы чата" subtitle:@"Просит подтверждение перед сменой темы чата" defaultsKey:@"change_direct_theme_confirm"],
                                                [SCISetting switchCellWithTitle:@"Подтверждать взаимодействие со стикерами" subtitle:@"Просит подтверждение перед нажатием на стикер в Story" defaultsKey:@"sticker_interact_confirm"]
                                            ]
                                        }]
                ]
            ]
        },
        @{
            @"header": @"",
            @"rows": @[
                // [SCISetting navigationCellWithTitle:@"Experimental"
                //                            subtitle:@""
                //                                icon:[SCISymbol symbolWithName:@"testtube.2"]
                //                         navSections:@[@{
                //                             @"header": @"Warning",
                //                             @"footer": @"These features are unstable and cause the Instagram app to crash unexpectedly.\n\nUse at your own risk!"
                //                         },
                //                         @{
                //                             @"header": @"",
                //                             @"rows": @[

                //                             ]
                //                         }
                //                         ]
                // ],
                [SCISetting navigationCellWithTitle:@"Отладка"
                                           subtitle:@""
                                               icon:[SCISymbol symbolWithName:@"ladybug"]
                                        navSections:@[@{
                                            @"header": @"FLEX",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Включить жест FLEX" subtitle:@"Удерживайте 5 пальцев для открытия FLEX" defaultsKey:@"flex_instagram"],
                                                [SCISetting switchCellWithTitle:@"Открывать FLEX при запуске" subtitle:@"Автоматически открывает FLEX при запуске приложения" defaultsKey:@"flex_app_launch"],
                                                [SCISetting switchCellWithTitle:@"Открывать FLEX при возврате в приложение" subtitle:@"Автоматически открывает FLEX при возврате в приложение" defaultsKey:@"flex_app_start"]
                                            ]
                                        },
                                        @{
                                            @"header": @"SCInsta",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Быстрый доступ к настройкам SCInsta" subtitle:@"Удерживайте кнопку «Главная», чтобы открыть настройки SCInsta" defaultsKey:@"settings_shortcut" requiresRestart:YES],
                                                [SCISetting switchCellWithTitle:@"Показывать настройки SCInsta при запуске" subtitle:@"Автоматически открывает настройки SCInsta при запуске" defaultsKey:@"tweak_settings_app_launch"],
                                                [SCISetting buttonCellWithTitle:@"Сбросить приветственный экран"
                                                                           subtitle:@""
                                                                               icon:nil
                                                                             action:^(void) { [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"SCInstaFirstRun"]; [SCIUtils showRestartConfirmation];}
                                                ],
                                            ]
                                        },
                                        @{
                                            @"header": @"Instagram",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Отключить безопасный режим" subtitle:@"Не даёт Instagram сбрасывать настройки после сбоев (на свой риск)" defaultsKey:@"disable_safe_mode"]
                                            ]
                                        },
                                        @{
                                            @"header": @"_ Example",
                                            @"rows": @[
                                                [SCISetting staticCellWithTitle:@"Static Cell" subtitle:@"" icon:[SCISymbol symbolWithName:@"tablecells"]],
                                                [SCISetting switchCellWithTitle:@"Switch Cell" subtitle:@"Tap the switch" defaultsKey:@"test_switch_cell"],
                                                [SCISetting switchCellWithTitle:@"Switch Cell (Restart)" subtitle:@"Tap the switch" defaultsKey:@"test_switch_cell_restart" requiresRestart:YES],
                                                [SCISetting stepperCellWithTitle:@"Stepper cell" subtitle:@"I have %@%@" defaultsKey:@"test_stepper_cell" min:-10 max:1000 step:5.5 label:@"$" singularLabel:@"$"],
                                                [SCISetting linkCellWithTitle:@"Link Cell" subtitle:@"Using icon" icon:[SCISymbol symbolWithName:@"link" color:[UIColor systemTealColor] size:20.0] url:@"https://google.com"],
                                                [SCISetting linkCellWithTitle:@"Link Cell" subtitle:@"Using image" imageUrl:@"https://i.imgur.com/c9CbytZ.png" url:@"https://google.com"],
                                                [SCISetting buttonCellWithTitle:@"Button Cell"
                                                                           subtitle:@""
                                                                               icon:[SCISymbol symbolWithName:@"oval.inset.filled"]
                                                                             action:^(void) { [SCIUtils showConfirmation:^(void){}]; }
                                                ],
                                                [SCISetting menuCellWithTitle:@"Menu Cell" subtitle:@"Change the value on the right" menu:[self menus][@"test"]],
                                                [SCISetting navigationCellWithTitle:@"Navigation Cell"
                                                                           subtitle:@""
                                                                               icon:[SCISymbol symbolWithName:@"rectangle.stack"]
                                                                        navSections:@[@{
                                                                            @"header": @"",
                                                                            @"rows": @[]
                                                                        }]
                                                ]
                                            ],
                                            @"footer": @"_ Example"
                                        }
                                        ]
                ]
            ]
        },
        @{
            @"header": @"О проекте",
            @"rows": @[
                [SCISetting linkCellWithTitle:@"Разработчик" subtitle:@"SoCuul" imageUrl:@"https://i.imgur.com/c9CbytZ.png" url:@"https://socuul.dev"],
                [SCISetting linkCellWithTitle:@"Открыть репозиторий" subtitle:@"Исходный код твика на GitHub" imageUrl:@"https://i.imgur.com/BBUNzeP.png" url:@"https://github.com/SoCuul/SCInsta"]
            ],
            @"footer": [NSString stringWithFormat:@"SCInsta %@\n\nInstagram v%@", SCIVersionString, [SCIUtils IGVersionString]]
        }
    ];
}


// MARK: - Title

///
/// This is the title displayed on the initial settings page view controller
///

+ (NSString *)title {
    return @"Настройки SCInsta";
}


// MARK: - Menus

///
/// This returns a dictionary where each key corresponds to a certain menu that can be displayed.
/// Each "propertyList"  item is an NSDictionary containing the following items:
///
/// `"defaultsKey"`: The key to save the selected value under in NSUserDefaults
///
/// `"value"`: A unique string corresponding to the menu item which is selected
///
/// `"requiresRestart"`: (optional) Causes a popup to appear detailing you have to restart to use these features
///

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"

+ (NSDictionary *)menus {
    return @{
        @"reels_tap_control": [UIMenu menuWithChildren:@[
            [UICommand commandWithTitle:@"По умолчанию"
                                    image:nil
                                    action:@selector(menuChanged:)
                            propertyList:@{
                                @"defaultsKey": @"reels_tap_control",
                                @"value": @"default",
                                @"requiresRestart": @YES
                            }
            ],
            [UIMenu menuWithTitle:@""
                            image:nil
                        identifier:nil
                            options:UIMenuOptionsDisplayInline
                            children:@[
                                [UICommand commandWithTitle:@"Пауза/Воспроизведение"
                                                        image:nil
                                                        action:@selector(menuChanged:)
                                                propertyList:@{
                                                    @"defaultsKey": @"reels_tap_control",
                                                    @"value": @"pause",
                                                    @"requiresRestart": @YES
                                                }
                                ],
                                [UICommand commandWithTitle:@"Выключить/Включить звук"
                                                        image:nil
                                                        action:@selector(menuChanged:)
                                                propertyList:@{
                                                    @"defaultsKey": @"reels_tap_control",
                                                    @"value": @"mute",
                                                    @"requiresRestart": @YES
                                                }
                                ]
                            ]
            ]
        ]],

        @"nav_icon_ordering": [UIMenu menuWithChildren:@[
            [UICommand commandWithTitle:@"По умолчанию"
                                    image:nil
                                    action:@selector(menuChanged:)
                            propertyList:@{
                                @"defaultsKey": @"nav_icon_ordering",
                                @"value": @"default",
                                @"requiresRestart": @YES
                            }
            ],
            [UIMenu menuWithTitle:@""
                            image:nil
                        identifier:nil
                            options:UIMenuOptionsDisplayInline
                            children:@[
                                [UICommand commandWithTitle:@"Классический"
                                                        image:nil
                                                        action:@selector(menuChanged:)
                                                propertyList:@{
                                                    @"defaultsKey": @"nav_icon_ordering",
                                                    @"value": @"classic",
                                                    @"requiresRestart": @YES
                                                }
                                ],
                                [UICommand commandWithTitle:@"Стандартный"
                                                        image:nil
                                                        action:@selector(menuChanged:)
                                                propertyList:@{
                                                    @"defaultsKey": @"nav_icon_ordering",
                                                    @"value": @"standard",
                                                    @"requiresRestart": @YES
                                                }
                                ],
                                [UICommand commandWithTitle:@"Альтернативный"
                                                        image:nil
                                                        action:@selector(menuChanged:)
                                                propertyList:@{
                                                    @"defaultsKey": @"nav_icon_ordering",
                                                    @"value": @"alternate",
                                                    @"requiresRestart": @YES
                                                }
                                ]
                            ]
            ]
        ]],
        @"swipe_nav_tabs": [UIMenu menuWithChildren:@[
            [UICommand commandWithTitle:@"По умолчанию"
                                    image:nil
                                    action:@selector(menuChanged:)
                            propertyList:@{
                                @"defaultsKey": @"swipe_nav_tabs",
                                @"value": @"default",
                                @"requiresRestart": @YES
                            }
            ],
            [UIMenu menuWithTitle:@""
                            image:nil
                        identifier:nil
                            options:UIMenuOptionsDisplayInline
                            children:@[
                                [UICommand commandWithTitle:@"Включено"
                                                        image:nil
                                                        action:@selector(menuChanged:)
                                                propertyList:@{
                                                    @"defaultsKey": @"swipe_nav_tabs",
                                                    @"value": @"enabled",
                                                    @"requiresRestart": @YES
                                                }
                                ],
                                [UICommand commandWithTitle:@"Выключено"
                                                        image:nil
                                                        action:@selector(menuChanged:)
                                                propertyList:@{
                                                    @"defaultsKey": @"swipe_nav_tabs",
                                                    @"value": @"disabled",
                                                    @"requiresRestart": @YES
                                                }
                                ]
                            ]
            ]
        ]],

        @"test": [UIMenu menuWithChildren:@[
            [UIMenu menuWithTitle:@""
                            image:nil
                        identifier:nil
                            options:UIMenuOptionsDisplayInline
                            children:@[
                                [UICommand commandWithTitle:@"ABC"
                                                        image:nil
                                                        action:@selector(menuChanged:)
                                                propertyList:@{
                                                    @"defaultsKey": @"test_menu_cell",
                                                    @"value": @"abc"
                                                }
                                ],
                                [UICommand commandWithTitle:@"123"
                                                        image:nil
                                                        action:@selector(menuChanged:)
                                                propertyList:@{
                                                    @"defaultsKey": @"test_menu_cell",
                                                    @"value": @"123"
                                                }
                                ]
                            ]
            ],
            [UICommand commandWithTitle:@"Требуется перезапуск"
                                  image:nil
                                 action:@selector(menuChanged:)
                           propertyList:@{
                               @"defaultsKey": @"test_menu_cell",
                               @"value": @"requires_restart",
                               @"requiresRestart": @YES
                           }
            ],
        ]]
    };
}

#pragma clang diagnostic pop

@end
