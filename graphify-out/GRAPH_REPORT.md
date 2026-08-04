# Graph Report - .  (2026-08-02)

## Corpus Check
- 3 files · ~135,670 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1334 nodes · 2569 edges · 75 communities (63 shown, 12 thin omitted)
- Extraction: 83% EXTRACTED · 17% INFERRED · 0% AMBIGUOUS · INFERRED: 447 edges (avg confidence: 0.8)
- Token cost: 0 input · 40,121 output

## Community Hubs (Navigation)
- main.cpp / string
- autosubsync.lua / mp.get_property()
- ar_subs.lua / enhanced_auto_fetch_if_need…
- mp.commandv() / mp.get_property_native()
- dynamic-crop.lua / run_scan()
- subdl.lua / match.lua
- Menu.lua / mp.set_property_bool()
- ar_subs (Arabic subtitle fe… / autosubsync (ffsubsync alig…
- memo.lua / show_history()
- SmartSkip.lua / prompt_msg()
- inputevent.lua / bind_from_options_configs()
- utils.parse_json() / http.lua
- thumbfast.lua / mp.command_native()
- cursor.lua / mp.get_time()
- menu.lua / sub-lang-filter.lua
- Volume.lua / Volume:render()
- Controls.lua / Button.lua
- Timeline.lua / load_youtube_heatmap()
- lib/utils.lua / navigate_playlist()
- std.lua / itable_clear()
- sponsorblock.lua / mp.osd_message()
- subtitle.lua / AbstractSubtitle:parse_file…
- TopBar.lua / expand_template()
- media.lua / M.classify_content_type()
- mp.lua / mp.observe_property()
- Element.lua / table_keys()
- Updater.lua / t()
- Elements.lua / buttons.lua
- store.lua / M.get()
- clamp() / Speed.lua
- fzy.lua / compute()
- menus.lua / get_all_user_bindings()
- text.lua / utf8_char_bytes()
- itable_index_of() / Menu:update()
- uosc/main.lua / handle_options()
- subtitle_api.lua / do_fetch()
- tvdb.lua / test_tvdb.lua
- localdb.lua / M.find_episode_subs()
- autochapters/main.lua / api_lookup()
- table_assign() / itable_join()
- is_protocol() / get_adjacent_files()
- request_render() / Menu:set_scroll_to()
- run.lua / _fmt()
- search_items() / utf8_iter()
- text_width() / Timeline:render()
- comma_split() / update_config()
- ass.lua / ass_mt:tooltip()
- activation.lua / zstd.lua
- mp.add_timeout() / screenshot()
- Controls:init_options() / itable_has()
- itable_find() / Menu:select_by_offset()
- config.lua / M.load()
- uosc_picker.lua / M.format_item()
- CycleButton:init() / CycleButton.lua
- wrap_text() / serialize_chapters()
- install.sh / need_cmd()
- Menu:search_cursor_move() / find_string_segment_bound()
- cuda-crop-cpp executable ta… / nlohmann_json dependency
- tween() / Element:tween()
- CLAUDE.md — mpv-conf projec…
- SmartSkip (OP/ED/Preview au…
- sponsorblock (YouTube only)
- memo (playback history)
- mpv-mpris (MPRIS media-key …
- uosc UI

## God Nodes (most connected - your core abstractions)
1. `request_render()` - 39 edges
2. `mp.commandv()` - 34 edges
3. `mp.get_property()` - 27 edges
4. `mp.get_property_native()` - 27 edges
5. `mp.set_property()` - 21 edges
6. `mp.command_native()` - 20 edges
7. `sync_subtitles()` - 19 edges
8. `mp.add_timeout()` - 18 edges
9. `AnalyzerConfig` - 17 edges
10. `utils.parse_json()` - 16 edges

## Surprising Connections (you probably didn't know these)
- `Timeline:clear_thumbnail()` --calls--> `mp.commandv()`  [INFERRED]
  scripts/uosc/elements/Timeline.lua → script-modules/ar_subs/test/stubs/mp.lua
- `Timeline:set_from_cursor()` --calls--> `mp.commandv()`  [INFERRED]
  scripts/uosc/elements/Timeline.lua → script-modules/ar_subs/test/stubs/mp.lua
- `Volume:render()` --calls--> `mp.commandv()`  [INFERRED]
  scripts/uosc/elements/Volume.lua → script-modules/ar_subs/test/stubs/mp.lua
- `load_track()` --calls--> `mp.commandv()`  [INFERRED]
  scripts/uosc/lib/utils.lua → script-modules/ar_subs/test/stubs/mp.lua
- `fast_forward()` --calls--> `mp.set_property()`  [INFERRED]
  scripts/sponsorblock.lua → script-modules/ar_subs/test/stubs/mp.lua

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **ar_subs three-source fetch waterfall** — readme_ar_subs, readme_subscene_offline_index, readme_subsource, readme_subdl [EXTRACTED 1.00]
- **Anime pipeline (detect -> profile -> Anime4K shaders)** — readme_anime_detect, readme_anime_profile, readme_anime4k, readme_shaders [EXTRACTED 1.00]
- **zstd compressed-at-rest cache convention** — readme_ar_subs, readme_autosubsync, readme_zstd_cache [INFERRED 0.85]
- **Playback-load pipeline stages (all fire off file-loaded)** — claude_playback_pipeline, claude_anime_detect, claude_ar_subs, claude_autosubsync, claude_dynamic_crop, claude_uosc [EXTRACTED 1.00]
- **Repo-specific mpv config gotchas and conventions** — claude_conditional_profiles, claude_msg_level_gotcha, claude_mp_options_sharing, claude_key_precedence, claude_lua_pattern_limits, claude_zstd_convention, claude_cache_integrity [INFERRED 0.85]
- **Dynamic crop C++ sidecar build chain** — cuda_crop_cpp_cmakelists_cudacropcpp, cuda_crop_cpp_cmakelists_nlohmannjson [EXTRACTED 1.00]

## Communities (75 total, 12 thin omitted)

### Community 0 - "main.cpp / string"
Cohesion: 0.06
Nodes (84): analyze_timeline_events(), AnalyzerConfig, current_crop, duration_seconds, gpu_id, min_votes, round_to, sample_step (+76 more)

### Community 1 - "autosubsync.lua / mp.get_property()"
Cohesion: 0.07
Nodes (54): mp.get_property(), decode_value(), encode_value(), skip_ws(), utils.file_info(), utils.format_json(), utils.join_path(), apply_cached_transform() (+46 more)

### Community 2 - "ar_subs.lua / enhanced_auto_fetch_if_need…"
Cohesion: 0.06
Nodes (56): M.migrate_keys(), M.stringify_keys(), apply_download_quota_block(), ar_subs_pick(), bump_type_count(), check_existing_season_files(), check_existing_subtitle_for_file(), count_arabic_subs() (+48 more)

### Community 3 - "mp.commandv() / mp.get_property_native()"
Cohesion: 0.07
Nodes (54): mp.commandv(), mp.get_property_native(), mp.set_property(), apply_crop(), cleanup(), collect_metadata(), command_filter(), compute_metadata() (+46 more)

### Community 4 - "dynamic-crop.lua / run_scan()"
Cohesion: 0.09
Nodes (58): apply_crop(), apply_render_crop(), apply_transform(), build_args(), build_request(), clamp(), clear_pending_events(), crop_parts() (+50 more)

### Community 5 - "subdl.lua / match.lua"
Cohesion: 0.06
Nodes (27): alternate_download_key(), auth_header(), auth_headers(), describe_download(), download_url_to_srt(), fetch(), get_utils(), is_zip_file() (+19 more)

### Community 6 - "Menu.lua / mp.set_property_bool()"
Cohesion: 0.05
Nodes (4): mp.set_property_bool(), Menu:close(), Menu:search_cancel(), Menu:search_init()

### Community 7 - "ar_subs (Arabic subtitle fe… / autosubsync (ffsubsync alig…"
Cohesion: 0.06
Nodes (39): [Anime] conditional profile (Anime4K v4.x Mode A), anime_detect.lua, ar_subs (Arabic subtitle fetch waterfall), autosubsync (ffsubsync alignment), Convention: autosubsync transform-cache tied to retimed path, Gotcha: conditional profiles need profile-restore=copy-equal, dynamic-crop.lua (CUDA sidecar backend), dynamic-crop-legacy.lua (cropdetect fallback) (+31 more)

### Community 8 - "memo.lua / show_history()"
Cohesion: 0.08
Nodes (26): ass_clean(), bind_keys(), close_menu(), draw_menu(), file_load(), get_full_path(), has_protocol(), memo_close() (+18 more)

### Community 9 - "SmartSkip.lua / prompt_msg()"
Cohesion: 0.12
Nodes (32): bake_chapters(), bind_keys(), chapterSeek(), chapterskip(), command_exists(), construct_ffmetadata(), detect_os(), eofHandler() (+24 more)

### Community 10 - "inputevent.lua / bind_from_options_configs()"
Cohesion: 0.09
Nodes (15): bind(), bind_from_conf(), bind_from_json(), bind_from_options_configs(), command(), command_invert(), command_split(), debounce() (+7 more)

### Community 11 - "utils.parse_json() / http.lua"
Cohesion: 0.11
Nodes (22): build_curl_args(), is_rate_limited(), M.request_async(), M.request_async_json(), parse_curl_output(), parse_json_response(), utils.parse_json(), curl_json() (+14 more)

### Community 12 - "thumbfast.lua / mp.command_native()"
Cohesion: 0.17
Nodes (24): mp.command_native(), calc_dimensions(), check_new_thumb(), clear(), draw(), file_load(), get_os(), info() (+16 more)

### Community 13 - "cursor.lua / mp.get_time()"
Cohesion: 0.10
Nodes (14): mp.get_time(), Element:update_proximity(), Speed:handle_cursor_down(), Timeline:on_global_mouse_move(), Updater:render(), cursor:collides_with(), cursor:_find_history_sample(), cursor:get_velocity() (+6 more)

### Community 14 - "menu.lua / sub-lang-filter.lua"
Cohesion: 0.12
Nodes (10): announce(), build_allowed(), cycle(), expand(), label(), norm(), on_track_list(), pick_default() (+2 more)

### Community 16 - "Controls.lua / Button.lua"
Cohesion: 0.09
Nodes (3): Button:handle_cursor_click(), Button:render(), Controls:update_dimensions()

### Community 17 - "Timeline.lua / load_youtube_heatmap()"
Cohesion: 0.08
Nodes (6): Timeline:clear_thumbnail(), Timeline:init(), Timeline:set_from_cursor(), Timeline:toggle_progress(), load_youtube_heatmap(), points_to_bezier()

### Community 18 - "lib/utils.lua / navigate_playlist()"
Cohesion: 0.13
Nodes (20): Menu:paste(), ass_mt.opacity(), cursor:direction_to_rectangle_distance(), call_ziggy(), decide_navigation_in_list(), delete_file(), delete_file_navigate(), get_clipboard() (+12 more)

### Community 19 - "std.lua / itable_clear()"
Cohesion: 0.09
Nodes (4): cursor:clear_zones(), CircularBuffer:clear(), itable_clear(), trim_end()

### Community 20 - "sponsorblock.lua / mp.osd_message()"
Cohesion: 0.21
Nodes (19): mp.command_native_async(), mp.osd_message(), utils.subprocess(), clean_chapters(), create_chapter(), fade_audio(), fast_forward(), file_exists() (+11 more)

### Community 21 - "subtitle.lua / AbstractSubtitle:parse_file…"
Cohesion: 0.10
Nodes (4): AbstractSubtitle:parse_file(), SRT.entry(), SRT:populate(), trim()

### Community 22 - "TopBar.lua / expand_template()"
Cohesion: 0.10
Nodes (6): expand_template(), TopBar:add_template_listener(), TopBar:register_observers(), TopBar:update_render_titles(), regexp_escape(), get_expansion_props()

### Community 23 - "media.lua / M.classify_content_type()"
Cohesion: 0.13
Nodes (8): best_type_from_counts(), M.classify_content_type(), M.clean_title(), M.extract_series_info(), M.normalize_path_key(), M.normalize_stem_key(), M.path_title_candidates(), M.resolve_media_info()

### Community 24 - "mp.lua / mp.observe_property()"
Cohesion: 0.13
Nodes (13): mp.add_periodic_timer(), mp.create_osd_overlay(), mp.observe_property(), mp.register_event(), delete_watch_later(), pause_timer_while_paused(), save(), save_if_pause() (+5 more)

### Community 25 - "Element.lua / table_keys()"
Cohesion: 0.11
Nodes (5): Element:flash(), Element:has_keybindings(), Element:remove_key_bindings(), Element:trigger(), table_keys()

### Community 26 - "Updater.lua / t()"
Cohesion: 0.14
Nodes (14): cleanup_output(), Updater:append_output(), Updater:check(), Updater:display_error(), Updater:init(), Updater:open_changelog(), Updater:select_next_button(), Updater:select_prev_button() (+6 more)

### Community 27 - "Elements.lua / buttons.lua"
Cohesion: 0.11
Nodes (5): Elements:add(), Elements:remove(), buttons:set(), buttons:unsubscribe(), itable_delete_value()

### Community 28 - "store.lua / M.get()"
Cohesion: 0.29
Nodes (15): exit_ok(), have_bin(), log(), M.del(), M.get(), M.init(), M.purge_older(), M.put() (+7 more)

### Community 29 - "clamp() / Speed.lua"
Cohesion: 0.12
Nodes (8): Menu:move_selected_item_by(), Menu:update_dimensions(), Speed:on_global_mouse_leave(), Speed:on_global_mouse_move(), Speed:render(), Timeline:get_time_at_x(), VolumeSlider:set_volume(), clamp()

### Community 30 - "fzy.lua / compute()"
Cohesion: 0.20
Nodes (8): compute(), fzy.filter(), fzy.has_match(), fzy.positions(), fzy.score(), is_lower(), is_upper(), precompute_bonus()

### Community 31 - "menus.lua / get_all_user_bindings()"
Cohesion: 0.21
Nodes (11): create_select_tracklist_type_menu_opener(), create_self_updating_menu_opener(), create_track_loader_menu_opener(), get_all_user_bindings(), get_keybinds_items(), get_menu_items(), is_uosc_menu_comment(), open_command_menu() (+3 more)

### Community 32 - "text.lua / utf8_char_bytes()"
Cohesion: 0.23
Nodes (12): char_length(), fit_on_screen(), get_roman_match_positions(), highlight_match(), text_length(), utf8_char_bytes(), utf8_charpos_to_bytepos(), utf8_next() (+4 more)

### Community 33 - "itable_index_of() / Menu:update()"
Cohesion: 0.15
Nodes (14): Controls:register_badge_updater(), Element:register_disposer(), Menu:activate_menu(), Menu:handle_shortcut(), Menu:reset_navigation(), Menu:update(), cursor:off(), cursor:on() (+6 more)

### Community 34 - "uosc/main.lua / handle_options()"
Cohesion: 0.22
Nodes (10): mp.add_key_binding(), timestamp_zero_rep_clear_cache(), bind_command(), create_state_setter(), handle_options(), set_state(), update_display_dimensions(), update_duration() (+2 more)

### Community 35 - "subtitle_api.lua / do_fetch()"
Cohesion: 0.26
Nodes (8): build_query(), do_fetch(), log(), M.candidates(), M.fetch(), M.url_encode(), parse_headers(), remove_quiet()

### Community 36 - "tvdb.lua / test_tvdb.lua"
Cohesion: 0.26
Nodes (8): auth_headers(), log(), M.login(), M.resolve_absolute(), M.search_series(), default_episodes_page(), default_login_response(), setup_provider()

### Community 37 - "localdb.lua / M.find_episode_subs()"
Cohesion: 0.30
Nodes (9): log(), M.find_episode_subs(), M.find_movie_subs(), M.init(), M.slug_candidates(), num(), query(), slugify() (+1 more)

### Community 38 - "autochapters/main.lua / api_lookup()"
Cohesion: 0.33
Nodes (10): api_lookup(), extract_mal_id(), file_load(), find_chapters(), guess(), log(), read_json(), resolve_relations() (+2 more)

### Community 39 - "table_assign() / itable_join()"
Cohesion: 0.17
Nodes (12): Element:init(), ManagedButton:init(), Menu:command_or_event(), Menu:scroll_to(), Menu:update_items(), itable_join(), table_assign(), table_copy() (+4 more)

### Community 40 - "is_protocol() / get_adjacent_files()"
Cohesion: 0.33
Nodes (12): string_last_index_of(), ensure_absolute(), get_adjacent_files(), has_any_extension(), is_protocol(), join_path(), normalize_path(), normalize_path_lite() (+4 more)

### Community 42 - "request_render() / Menu:set_scroll_to()"
Cohesion: 0.18
Nodes (11): Menu:activate_index(), Menu:deactivate_items(), Menu:handle_cursor_up(), Menu:navigate_action(), Menu:on_global_mouse_move(), Menu:search_trigger(), Menu:select_action(), Menu:select_index() (+3 more)

### Community 43 - "run.lua / _fmt()"
Cohesion: 0.29
Nodes (5): _fmt(), harness.eq(), harness.eq_n(), harness.same(), _same()

### Community 44 - "search_items() / utf8_iter()"
Cohesion: 0.29
Nodes (9): Menu:search_internal(), search_items(), char_conv(), get_romanization_table(), need_romanization(), character_based_width(), initials(), utf8_iter() (+1 more)

### Community 45 - "text_width() / Timeline:render()"
Cohesion: 0.29
Nodes (10): Menu:update_content_dimensions(), Timeline:render(), TopBar:render(), ass_mt:timestamp(), get_cache_stage(), no_remeasure_required(), text_width(), timestamp_width() (+2 more)

### Community 46 - "comma_split() / update_config()"
Cohesion: 0.27
Nodes (9): get_languages(), get_locale_from_json(), comma_split(), itable_append(), itable_map(), serialize_key_value_list(), serialize_rgba(), update_config() (+1 more)

### Community 50 - "mp.add_timeout() / screenshot()"
Cohesion: 0.32
Nodes (7): mp.add_timeout(), on_sid_changed(), safe_name(), screenshot(), timecode(), Menu:init(), Timeline:flash_progress()

### Community 51 - "Controls:init_options() / itable_has()"
Cohesion: 0.29
Nodes (7): Controls:init_options(), Curtain:unregister(), Elements:flash(), TopBar:select_current_chapter(), itable_filter(), itable_has(), itable_slice()

### Community 52 - "itable_find() / Menu:select_by_offset()"
Cohesion: 0.29
Nodes (7): Elements:toggle(), Menu:activate_one_value(), Menu:activate_value(), Menu:delete_value(), Menu:select_by_offset(), Menu:select_value(), itable_find()

### Community 53 - "config.lua / M.load()"
Cohesion: 0.40
Nodes (4): M.load(), M.read_dotenv(), mp.get_script_name(), options.read_options()

### Community 54 - "uosc_picker.lua / M.format_item()"
Cohesion: 0.60
Nodes (3): format_score(), M.build_menu(), M.format_item()

### Community 56 - "CycleButton:init() / CycleButton.lua"
Cohesion: 0.50
Nodes (3): CycleButton:init(), yes_no_to_boolean(), trim()

### Community 57 - "wrap_text() / serialize_chapters()"
Cohesion: 0.40
Nodes (5): normalized_to_real(), opts_factor_offset(), wrap_text(), normalize_chapters(), serialize_chapters()

### Community 60 - "Menu:search_cursor_move() / find_string_segment_bound()"
Cohesion: 0.50
Nodes (4): Menu:search_cursor_move(), Menu:search_query_backspace(), Menu:search_query_delete(), find_string_segment_bound()

## Knowledge Gaps
- **55 isolated node(s):** `cuda-crop-cpp executable target`, `nlohmann_json dependency`, `width`, `height`, `x` (+50 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **12 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `mp.commandv()` connect `mp.commandv() / mp.get_property_native()` to `autosubsync.lua / mp.get_property()`, `memo.lua / show_history()`, `is_protocol() / get_adjacent_files()`, `thumbfast.lua / mp.command_native()`, `text_width() / Timeline:render()`, `cursor.lua / mp.get_time()`, `Volume.lua / Volume:render()`, `comma_split() / update_config()`, `Timeline.lua / load_youtube_heatmap()`, `lib/utils.lua / navigate_playlist()`, `mp.lua / mp.observe_property()`, `CycleButton:init() / CycleButton.lua`, `clamp() / Speed.lua`?**
  _High betweenness centrality (0.093) - this node is a cross-community bridge._
- **Why does `mp.get_time()` connect `cursor.lua / mp.get_time()` to `autosubsync.lua / mp.get_property()`, `table_assign() / itable_join()`, `memo.lua / show_history()`, `inputevent.lua / bind_from_options_configs()`, `request_render() / Menu:set_scroll_to()`, `mp.lua / mp.observe_property()`, `Updater.lua / t()`?**
  _High betweenness centrality (0.068) - this node is a cross-community bridge._
- **Why does `mp.command_native()` connect `thumbfast.lua / mp.command_native()` to `autosubsync.lua / mp.get_property()`, `table_assign() / itable_join()`, `inputevent.lua / bind_from_options_configs()`, `comma_split() / update_config()`, `mp.add_timeout() / screenshot()`, `lib/utils.lua / navigate_playlist()`, `sponsorblock.lua / mp.osd_message()`, `config.lua / M.load()`, `TopBar.lua / expand_template()`, `mp.lua / mp.observe_property()`, `Updater.lua / t()`?**
  _High betweenness centrality (0.057) - this node is a cross-community bridge._
- **Are the 38 inferred relationships involving `request_render()` (e.g. with `Controls:update_dimensions()` and `Element:flash()`) actually correct?**
  _`request_render()` has 38 INFERRED edges - model-reasoned connections that need verification._
- **Are the 33 inferred relationships involving `mp.commandv()` (e.g. with `apply_crop()` and `cleanup()`) actually correct?**
  _`mp.commandv()` has 33 INFERRED edges - model-reasoned connections that need verification._
- **Are the 26 inferred relationships involving `mp.get_property()` (e.g. with `apply_crop()` and `on_start()`) actually correct?**
  _`mp.get_property()` has 26 INFERRED edges - model-reasoned connections that need verification._
- **Are the 26 inferred relationships involving `mp.get_property_native()` (e.g. with `apply_crop()` and `filter_state()`) actually correct?**
  _`mp.get_property_native()` has 26 INFERRED edges - model-reasoned connections that need verification._