# Graph Report - .  (2026-08-01)

## Corpus Check
- 96 files · ~127,277 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1278 nodes · 2688 edges · 73 communities (64 shown, 9 thin omitted)
- Extraction: 76% EXTRACTED · 24% INFERRED · 0% AMBIGUOUS · INFERRED: 635 edges (avg confidence: 0.8)
- Token cost: 21,011 input · 0 output

## Community Hubs (Navigation)
- CUDA Crop Analyzer
- Dynamic Crop Orchestrator
- Autosubsync Core
- ar_subs Runtime Cache
- SponsorBlock Script
- uosc Timeline
- uosc Menu Core
- ar_subs HTTP Client
- Memo History Menu
- uosc Tracklist Utils
- Input Event Script
- SmartSkip Auto-Skip
- SubDL Provider
- uosc Elements Intl
- uosc Stdlib
- uosc Volume
- Legacy Crop Fallback
- Anime Stack Docs
- Autosubsync Subtitle Model
- uosc Menu Navigation
- uosc TopBar
- uosc Speed Element
- uosc Element Base
- ar_subs SQLite Store
- ar_subs Download Load
- Media Type Classifier
- uosc Controls Updater
- uosc Text Utils
- Test mp Stub
- uosc Controls
- Fuzzy Matcher
- Autosubsync Cache Paths
- Thumbfast Script
- TVDB Provider
- Episode Match Tests
- Save-State and Evafast
- Local Subscene Index
- No-Index Seek
- uosc Menus Module
- Autosubsync Sync Flow
- ASS Drawing Lib
- Test Harness
- uosc Shortcuts Items
- uosc Elements Collection
- Char Conversion Search
- uosc Rendering
- Anime Detector
- uosc Button
- Activation zstd Tests
- URL Utils Tests
- uosc Button Mgmt
- uosc Value Menus
- uosc Pause Indicator
- Auto Deinterlace
- uosc Cursor Disposers
- Config Dotenv Loader
- uosc Picker Tests
- uosc Cycle Button
- Install Script
- Space Hold Speed
- Menu Search Cursor
- Arabic Keyboard Shortcuts

## God Nodes (most connected - your core abstractions)
1. `mp.commandv()` - 50 edges
2. `mp.get_property_native()` - 49 edges
3. `mp.get_property()` - 43 edges
4. `request_render()` - 39 edges
5. `mp.set_property()` - 36 edges
6. `mp.command_native()` - 31 edges
7. `mp.osd_message()` - 30 edges
8. `mp.add_timeout()` - 28 edges
9. `utils.file_info()` - 24 edges
10. `utils.parse_json()` - 20 edges

## Surprising Connections (you probably didn't know these)
- `handle_key()` --calls--> `mp.commandv()`  [INFERRED]
  scripts/ar_shortcuts.lua → script-modules/ar_subs/test/stubs/mp.lua
- `Timeline:clear_thumbnail()` --calls--> `mp.commandv()`  [INFERRED]
  scripts/uosc/elements/Timeline.lua → script-modules/ar_subs/test/stubs/mp.lua
- `Timeline:set_from_cursor()` --calls--> `mp.commandv()`  [INFERRED]
  scripts/uosc/elements/Timeline.lua → script-modules/ar_subs/test/stubs/mp.lua
- `Volume:render()` --calls--> `mp.commandv()`  [INFERRED]
  scripts/uosc/elements/Volume.lua → script-modules/ar_subs/test/stubs/mp.lua
- `PauseIndicator:flash()` --calls--> `mp.get_property_native()`  [INFERRED]
  scripts/uosc/elements/PauseIndicator.lua → script-modules/ar_subs/test/stubs/mp.lua

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **ar_subs ordered source fallback chain** — readme_arsubs, readme_subsceneindex, readme_subsource, readme_subdl [EXTRACTED 1.00]
- **Anime shader stack (always-on + Anime4K chain)** — readme_krigbilateral, readme_ssimsuperres, readme_ssimdownscaler, readme_anime4k [EXTRACTED 1.00]
- **Dynamic crop C++ sidecar build chain** — readme_dynamiccrop, cuda_crop_cpp_cmakelists_cudacropcpp, cuda_crop_cpp_cmakelists_nlohmannjson [EXTRACTED 1.00]

## Communities (73 total, 9 thin omitted)

### Community 0 - "CUDA Crop Analyzer"
Cohesion: 0.06
Nodes (84): analyze_timeline_events(), AnalyzerConfig, current_crop, duration_seconds, gpu_id, min_votes, round_to, sample_step (+76 more)

### Community 1 - "Dynamic Crop Orchestrator"
Cohesion: 0.09
Nodes (58): apply_crop(), apply_render_crop(), apply_transform(), build_args(), build_request(), clamp(), clear_pending_events(), crop_parts() (+50 more)

### Community 2 - "Autosubsync Core"
Cohesion: 0.07
Nodes (43): utils.file_info(), ass_time_to_sec(), auto_sync(), auto_sync_on_load(), cue_start_times(), djb2_hex(), dynamic_sync_window(), engine_is_set() (+35 more)

### Community 3 - "ar_subs Runtime Cache"
Cohesion: 0.07
Nodes (41): M.migrate_keys(), M.stringify_keys(), bump_type_count(), check_existing_season_files(), check_existing_subtitle_for_file(), count_arabic_subs(), execute_search_strategies(), fetch_bulk_subs() (+33 more)

### Community 4 - "SponsorBlock Script"
Cohesion: 0.10
Nodes (42): mp.command_native(), mp.command_native_async(), utils.subprocess(), clean_chapters(), create_chapter(), fade_audio(), fast_forward(), file_exists() (+34 more)

### Community 5 - "uosc Timeline"
Cohesion: 0.05
Nodes (18): mp.get_time(), Element:update_proximity(), Speed:handle_cursor_down(), Timeline:clear_thumbnail(), Timeline:flash_progress(), Timeline:on_global_mouse_move(), Timeline:set_from_cursor(), Timeline:toggle_progress() (+10 more)

### Community 6 - "uosc Menu Core"
Cohesion: 0.05
Nodes (4): Menu:close(), Menu:init(), Menu:paste(), Menu:search_cancel()

### Community 7 - "ar_subs HTTP Client"
Cohesion: 0.08
Nodes (26): build_curl_args(), is_rate_limited(), M.request_async(), M.request_async_json(), parse_curl_output(), parse_json_response(), decode_value(), encode_value() (+18 more)

### Community 8 - "Memo History Menu"
Cohesion: 0.08
Nodes (26): ass_clean(), bind_keys(), close_menu(), draw_menu(), file_load(), get_full_path(), has_protocol(), memo_close() (+18 more)

### Community 9 - "uosc Tracklist Utils"
Cohesion: 0.14
Nodes (31): Timeline:init(), cursor:direction_to_rectangle_distance(), create_track_loader_menu_opener(), decide_navigation_in_list(), delete_file(), delete_file_navigate(), ensure_absolute(), get_adjacent_files() (+23 more)

### Community 10 - "Input Event Script"
Cohesion: 0.09
Nodes (15): bind(), bind_from_conf(), bind_from_json(), bind_from_options_configs(), command(), command_invert(), command_split(), debounce() (+7 more)

### Community 11 - "SmartSkip Auto-Skip"
Cohesion: 0.20
Nodes (29): mp.add_timeout(), mp.commandv(), mp.set_property(), manual_search(), bind_keys(), chapterSeek(), chapterskip(), eofHandler() (+21 more)

### Community 12 - "SubDL Provider"
Cohesion: 0.15
Nodes (20): alternate_download_key(), auth_header(), auth_headers(), describe_download(), download_url_to_srt(), fetch(), get_utils(), is_zip_file() (+12 more)

### Community 13 - "uosc Elements Intl"
Cohesion: 0.12
Nodes (24): Element:has_keybindings(), Element:remove_key_bindings(), Menu:command_or_event(), Menu:update(), Updater:open_changelog(), get_languages(), get_locale_from_json(), open_subtitle_downloader() (+16 more)

### Community 14 - "uosc Stdlib"
Cohesion: 0.08
Nodes (6): TopBar:update_render_titles(), cursor:clear_zones(), CircularBuffer:clear(), itable_clear(), regexp_escape(), trim_end()

### Community 16 - "Legacy Crop Fallback"
Cohesion: 0.25
Nodes (22): apply_crop(), cleanup(), collect_metadata(), command_filter(), compute_metadata(), filter_state(), generate_ratios(), insert_cropdetect_filter() (+14 more)

### Community 17 - "Anime Stack Docs"
Cohesion: 0.10
Nodes (22): cuda-crop-cpp executable target, nlohmann_json dependency, Anime4K v4.x Mode A shader chain, anime_detect.lua — anime classifier, [Anime] auto profile, Anime stack (shaders + auto profile + SmartSkip), ar_subs — Arabic subtitle system, autosubsync — automatic subtitle timing (+14 more)

### Community 18 - "Autosubsync Subtitle Model"
Cohesion: 0.10
Nodes (4): AbstractSubtitle:parse_file(), SRT.entry(), SRT:populate(), trim()

### Community 19 - "uosc Menu Navigation"
Cohesion: 0.13
Nodes (15): Menu:activate_index(), Menu:deactivate_items(), Menu:handle_cursor_up(), Menu:navigate_action(), Menu:on_global_mouse_move(), Menu:search_trigger(), Menu:select_action(), Menu:select_index() (+7 more)

### Community 20 - "uosc TopBar"
Cohesion: 0.11
Nodes (5): expand_template(), TopBar:add_template_listener(), TopBar:register_observers(), ass_escape(), get_expansion_props()

### Community 21 - "uosc Speed Element"
Cohesion: 0.11
Nodes (10): Menu:move_selected_item_by(), Menu:set_scroll_to(), Menu:update_dimensions(), Speed:handle_cursor_up(), Speed:on_global_mouse_leave(), Speed:on_global_mouse_move(), Speed:render(), Timeline:get_time_at_x() (+2 more)

### Community 22 - "uosc Element Base"
Cohesion: 0.11
Nodes (4): Element:flash(), Element:trigger(), Element:tween(), tween()

### Community 23 - "ar_subs SQLite Store"
Cohesion: 0.29
Nodes (15): exit_ok(), have_bin(), log(), M.del(), M.get(), M.init(), M.purge_older(), M.put() (+7 more)

### Community 24 - "ar_subs Download Load"
Cohesion: 0.24
Nodes (17): mp.create_osd_overlay(), mp.osd_message(), basename(), apply_download_quota_block(), ar_subs_pick(), download_and_load(), enhanced_auto_fetch_if_needed(), fetch_next_sub() (+9 more)

### Community 25 - "Media Type Classifier"
Cohesion: 0.16
Nodes (8): best_type_from_counts(), M.classify_content_type(), M.clean_title(), M.extract_series_info(), M.normalize_path_key(), M.normalize_stem_key(), M.path_title_candidates(), M.resolve_media_info()

### Community 26 - "uosc Controls Updater"
Cohesion: 0.16
Nodes (17): Controls:init_options(), Elements:flash(), Updater:display_error(), Updater:init(), t(), create_select_tracklist_type_menu_opener(), create_self_updating_menu_opener(), open_file_navigation_menu() (+9 more)

### Community 27 - "uosc Text Utils"
Cohesion: 0.20
Nodes (14): char_length(), fit_on_screen(), get_roman_match_positions(), highlight_match(), normalized_to_real(), opts_factor_offset(), text_length(), utf8_char_bytes() (+6 more)

### Community 28 - "Test mp Stub"
Cohesion: 0.16
Nodes (10): mp.observe_property(), mp.register_event(), delete_watch_later(), safe_name(), screenshot(), timecode(), Element:observe_mp_property(), Element:register_mp_event() (+2 more)

### Community 30 - "Fuzzy Matcher"
Cohesion: 0.20
Nodes (8): compute(), fzy.filter(), fzy.has_match(), fzy.positions(), fzy.score(), is_lower(), is_upper(), precompute_bonus()

### Community 31 - "Autosubsync Cache Paths"
Cohesion: 0.22
Nodes (14): mp.get_property(), utils.join_path(), apply_cached_transform(), get_extension(), mkfp_retimed(), remove_extension(), bake_chapters(), command_exists() (+6 more)

### Community 33 - "Thumbfast Script"
Cohesion: 0.22
Nodes (10): mp.add_key_binding(), timestamp_zero_rep_clear_cache(), bind_command(), create_state_setter(), handle_options(), set_state(), update_display_dimensions(), update_duration() (+2 more)

### Community 34 - "TVDB Provider"
Cohesion: 0.26
Nodes (8): auth_headers(), log(), M.login(), M.resolve_absolute(), M.search_series(), default_episodes_page(), default_login_response(), setup_provider()

### Community 35 - "Episode Match Tests"
Cohesion: 0.23
Nodes (5): M.add_episode_meta(), M.add_pair_meta(), M.expand_unpack_files(), M.normalize_subtitle_metadata(), M.normalize_subtitles_metadata()

### Community 36 - "Save-State and Evafast"
Cohesion: 0.26
Nodes (10): mp.add_periodic_timer(), pause_timer_while_paused(), save(), save_if_pause(), adjust_speed(), evafast(), evafast_slowdown(), evafast_speedup() (+2 more)

### Community 37 - "Local Subscene Index"
Cohesion: 0.30
Nodes (9): log(), M.find_episode_subs(), M.find_movie_subs(), M.init(), M.slug_candidates(), num(), query(), slugify() (+1 more)

### Community 38 - "No-Index Seek"
Cohesion: 0.30
Nodes (10): best_jump_point(), do_seek(), fast_seek_to(), format_time(), index_path(), load_index(), make_abs_seek(), make_rel_seek() (+2 more)

### Community 39 - "uosc Menus Module"
Cohesion: 0.30
Nodes (11): Curtain:unregister(), get_all_user_bindings(), get_keybinds_items(), get_menu_items(), is_uosc_menu_comment(), open_command_menu(), toggle_menu_with_items(), itable_filter() (+3 more)

### Community 40 - "Autosubsync Sync Flow"
Cohesion: 0.22
Nodes (11): mp.get_property_native(), mp.set_property_bool(), audio_is_cheap(), on_sid_changed(), hold_startup_until_first_scan(), add_chapter(), change_title_callback(), edit_chapter() (+3 more)

### Community 42 - "ASS Drawing Lib"
Cohesion: 0.18
Nodes (4): ass_mt.opacity(), ass_mt:spinner(), ass_mt:tooltip(), opacity_to_alpha()

### Community 43 - "Test Harness"
Cohesion: 0.29
Nodes (5): _fmt(), harness.eq(), harness.eq_n(), harness.same(), _same()

### Community 44 - "uosc Shortcuts Items"
Cohesion: 0.20
Nodes (10): Element:init(), ManagedButton:init(), Menu:handle_shortcut(), Menu:scroll_to(), Menu:update_items(), create_shortcut(), string_last_index_of(), table_assign() (+2 more)

### Community 46 - "Char Conversion Search"
Cohesion: 0.29
Nodes (9): Menu:search_internal(), search_items(), char_conv(), get_romanization_table(), need_romanization(), character_based_width(), initials(), utf8_iter() (+1 more)

### Community 47 - "uosc Rendering"
Cohesion: 0.29
Nodes (10): Menu:update_content_dimensions(), Timeline:render(), TopBar:render(), ass_mt:timestamp(), get_cache_stage(), no_remeasure_required(), text_width(), timestamp_width() (+2 more)

### Community 48 - "Anime Detector"
Cohesion: 0.50
Nodes (8): curl_json(), has_japanese_audio(), is_video(), log(), normalize(), on_loaded(), probe(), title_from_path()

### Community 53 - "uosc Button Mgmt"
Cohesion: 0.25
Nodes (4): Elements:remove(), buttons:set(), buttons:unsubscribe(), itable_delete_value()

### Community 54 - "uosc Value Menus"
Cohesion: 0.25
Nodes (8): Elements:toggle(), Menu:activate_one_value(), Menu:activate_value(), Menu:delete_value(), Menu:select_by_offset(), Menu:select_value(), TopBar:select_current_chapter(), itable_find()

### Community 56 - "Auto Deinterlace"
Cohesion: 0.62
Nodes (6): add_vf(), del_filter_if_present(), judge(), select_filter(), start_detect(), stop_detect()

### Community 57 - "uosc Cursor Disposers"
Cohesion: 0.29
Nodes (7): Controls:register_badge_updater(), Element:register_disposer(), Menu:activate_menu(), Menu:reset_navigation(), cursor:off(), cursor:on(), itable_index_of()

### Community 58 - "Config Dotenv Loader"
Cohesion: 0.40
Nodes (4): M.load(), M.read_dotenv(), mp.get_script_name(), options.read_options()

### Community 59 - "uosc Picker Tests"
Cohesion: 0.60
Nodes (3): format_score(), M.build_menu(), M.format_item()

### Community 61 - "uosc Cycle Button"
Cohesion: 0.50
Nodes (3): CycleButton:init(), yes_no_to_boolean(), trim()

### Community 65 - "Space Hold Speed"
Cohesion: 1.00
Nodes (3): flash_speed(), on_space(), restore_state()

### Community 66 - "Menu Search Cursor"
Cohesion: 0.50
Nodes (4): Menu:search_cursor_move(), Menu:search_query_backspace(), Menu:search_query_delete(), find_string_segment_bound()

## Knowledge Gaps
- **46 isolated node(s):** `width`, `height`, `x`, `y`, `crop` (+41 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **9 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `mp.commandv()` connect `SmartSkip Auto-Skip` to `Dynamic Crop Orchestrator`, `Autosubsync Core`, `ar_subs Runtime Cache`, `SponsorBlock Script`, `uosc Timeline`, `Memo History Menu`, `uosc Tracklist Utils`, `uosc Elements Intl`, `uosc Volume`, `Legacy Crop Fallback`, `uosc Speed Element`, `ar_subs Download Load`, `uosc Controls Updater`, `Test mp Stub`, `Autosubsync Cache Paths`, `Save-State and Evafast`, `No-Index Seek`, `uosc Rendering`, `uosc Cycle Button`, `Arabic Keyboard Shortcuts`?**
  _High betweenness centrality (0.120) - this node is a cross-community bridge._
- **Why does `mp.get_property_native()` connect `Autosubsync Sync Flow` to `Dynamic Crop Orchestrator`, `Autosubsync Core`, `ar_subs Runtime Cache`, `SponsorBlock Script`, `uosc Timeline`, `Memo History Menu`, `uosc Tracklist Utils`, `Input Event Script`, `SmartSkip Auto-Skip`, `uosc Elements Intl`, `Legacy Crop Fallback`, `ar_subs Download Load`, `uosc Controls Updater`, `Test mp Stub`, `Autosubsync Cache Paths`, `Save-State and Evafast`, `No-Index Seek`, `uosc Menus Module`, `Anime Detector`, `uosc Pause Indicator`, `Auto Deinterlace`, `Space Hold Speed`?**
  _High betweenness centrality (0.079) - this node is a cross-community bridge._
- **Why does `mp.get_time()` connect `uosc Timeline` to `Dynamic Crop Orchestrator`, `Autosubsync Core`, `Memo History Menu`, `Input Event Script`, `uosc Shortcuts Items`, `uosc Menu Navigation`, `uosc Controls Updater`, `Test mp Stub`?**
  _High betweenness centrality (0.067) - this node is a cross-community bridge._
- **Are the 49 inferred relationships involving `mp.commandv()` (e.g. with `apply_crop()` and `cleanup()`) actually correct?**
  _`mp.commandv()` has 49 INFERRED edges - model-reasoned connections that need verification._
- **Are the 48 inferred relationships involving `mp.get_property_native()` (e.g. with `apply_crop()` and `filter_state()`) actually correct?**
  _`mp.get_property_native()` has 48 INFERRED edges - model-reasoned connections that need verification._
- **Are the 42 inferred relationships involving `mp.get_property()` (e.g. with `apply_crop()` and `on_start()`) actually correct?**
  _`mp.get_property()` has 42 INFERRED edges - model-reasoned connections that need verification._
- **Are the 38 inferred relationships involving `request_render()` (e.g. with `Controls:update_dimensions()` and `Element:flash()`) actually correct?**
  _`request_render()` has 38 INFERRED edges - model-reasoned connections that need verification._