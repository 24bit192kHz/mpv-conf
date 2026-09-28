# Graph Report - mpv  (2026-09-28)

## Corpus Check
- 108 files · ~157,078 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1503 nodes · 3160 edges · 71 communities (57 shown, 14 thin omitted)
- Extraction: 80% EXTRACTED · 20% INFERRED · 0% AMBIGUOUS · INFERRED: 647 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `54c0d82a`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- main.cpp
- autosubsync.lua
- ar_subs.lua
- mp.commandv() / mp.get_property_native()
- dynamic-crop.lua
- subdl.lua
- Menu.lua
- ar_subs (Arabic subtitle fe… / autosubsync (ffsubsync alig…
- memo.lua / show_history()
- mp.get_property_native
- inputevent.lua
- utils.parse_json
- mp.command_native
- cursor.lua
- menu.lua
- Controls.lua
- Timeline.lua
- lib/utils.lua
- std.lua
- request_render
- subtitle.lua / AbstractSubtitle:parse_file…
- TopBar.lua
- media.lua
- table_assign
- Element.lua
- Updater.lua
- Elements.lua
- store.lua / M.get()
- mp.set_property_native
- fzy.lua / compute()
- t
- text.lua
- clipshot.lua
- uosc/main.lua
- subtitle_api.lua / do_fetch()
- tvdb.lua / test_tvdb.lua
- localdb.lua / M.find_episode_subs()
- timing_ref.py
- Button.lua
- CycleButton:init
- cursor:trigger
- run.lua / _fmt()
- no-index-seek.lua
- zstd.lua
- itable_find() / Menu:select_by_offset()
- uosc_picker.lua / M.format_item()
- Curtain.lua
- install.sh / need_cmd()
- cuda-crop-cpp executable ta… / nlohmann_json dependency
- sub-lang-filter.lua
- CLAUDE.md — mpv-conf projec…
- SmartSkip (OP/ED/Preview au…
- sponsorblock (YouTube only)
- memo (playback history)
- mpv-mpris (MPRIS media-key …
- uosc UI
- cache.lua
- curl_secrets.lua
- compare_from_history.py
- AGENTS.md
- GEMINI.md

## God Nodes (most connected - your core abstractions)
1. `mp.get_property_native()` - 57 edges
2. `mp.get_property()` - 53 edges
3. `request_render()` - 39 edges
4. `mp.osd_message()` - 37 edges
5. `mp.command_native()` - 36 edges
6. `mp.add_timeout()` - 31 edges
7. `utils.file_info()` - 31 edges
8. `mp.set_property_native()` - 28 edges
9. `utils.parse_json()` - 26 edges
10. `Cue` - 20 edges

## Surprising Connections (you probably didn't know these)
- `Menu:close()` --calls--> `mp.set_property_bool()`  [INFERRED]
  scripts/uosc/elements/Menu.lua → script-modules/ar_subs/test/stubs/mp.lua
- `Menu:search_cancel()` --calls--> `mp.set_property_bool()`  [INFERRED]
  scripts/uosc/elements/Menu.lua → script-modules/ar_subs/test/stubs/mp.lua
- `Element:register_mp_event()` --calls--> `mp.register_event()`  [INFERRED]
  scripts/uosc/elements/Element.lua → script-modules/ar_subs/test/stubs/mp.lua
- `Button:handle_cursor_click()` --calls--> `mp.add_timeout()`  [INFERRED]
  scripts/uosc/elements/Button.lua → script-modules/ar_subs/test/stubs/mp.lua
- `anime_detect.lua` --semantically_similar_to--> `anime_detect.lua (TMDB anime classifier)`  [INFERRED] [semantically similar]
  CLAUDE.md → README.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **ar_subs three-source fetch waterfall** — readme_ar_subs, readme_subscene_offline_index, readme_subsource, readme_subdl [EXTRACTED 1.00]
- **Anime pipeline (detect -> profile -> Anime4K shaders)** — readme_anime_detect, readme_anime_profile, readme_anime4k, readme_shaders [EXTRACTED 1.00]
- **zstd compressed-at-rest cache convention** — readme_ar_subs, readme_autosubsync, readme_zstd_cache [INFERRED 0.85]
- **Playback-load pipeline stages (all fire off file-loaded)** — claude_playback_pipeline, claude_anime_detect, claude_ar_subs, claude_autosubsync, claude_dynamic_crop, claude_uosc [EXTRACTED 1.00]
- **Repo-specific mpv config gotchas and conventions** — claude_conditional_profiles, claude_msg_level_gotcha, claude_mp_options_sharing, claude_key_precedence, claude_lua_pattern_limits, claude_zstd_convention, claude_cache_integrity [INFERRED 0.85]
- **Dynamic crop C++ sidecar build chain** — cuda_crop_cpp_cmakelists_cudacropcpp, cuda_crop_cpp_cmakelists_nlohmannjson [EXTRACTED 1.00]

## Communities (71 total, 14 thin omitted)

### Community 0 - "main.cpp"
Cohesion: 0.06
Nodes (86): analyze_timeline_events(), AnalyzerConfig, current_crop, duration_seconds, gpu_id, min_votes, round_to, sample_step (+78 more)

### Community 1 - "autosubsync.lua"
Cohesion: 0.06
Nodes (71): decode_value(), encode_value(), skip_ws(), utils.file_info(), utils.format_json(), utils.join_path(), apply_cached_transform(), ass_time_to_sec() (+63 more)

### Community 2 - "ar_subs.lua"
Cohesion: 0.05
Nodes (84): mp.get_property(), mp.osd_message(), utils.subprocess(), basename(), air_day(), anime_season_unknown(), apply_download_quota_block(), ar_subs_next_handler() (+76 more)

### Community 3 - "mp.commandv() / mp.get_property_native()"
Cohesion: 0.25
Nodes (22): apply_crop(), cleanup(), collect_metadata(), command_filter(), compute_metadata(), filter_state(), generate_ratios(), insert_cropdetect_filter() (+14 more)

### Community 4 - "dynamic-crop.lua"
Cohesion: 0.07
Nodes (62): mp.set_property_number(), apply_crop(), apply_render_crop(), apply_subtitle_crop(), apply_transform(), build_args(), build_request(), cancel_pending_near() (+54 more)

### Community 5 - "subdl.lua"
Cohesion: 0.05
Nodes (39): M.load(), M.read_dotenv(), alternate_download_key(), auth_header(), auth_headers(), describe_download(), download_url_to_srt(), fetch() (+31 more)

### Community 6 - "Menu.lua"
Cohesion: 0.05
Nodes (9): Menu:close(), Menu:command_or_event(), Menu:handle_shortcut(), Menu:paste(), Menu:search_cancel(), Menu:search_cursor_move(), Menu:search_query_backspace(), Menu:search_query_delete() (+1 more)

### Community 7 - "ar_subs (Arabic subtitle fe… / autosubsync (ffsubsync alig…"
Cohesion: 0.06
Nodes (39): [Anime] conditional profile (Anime4K v4.x Mode A), anime_detect.lua, ar_subs (Arabic subtitle fetch waterfall), autosubsync (ffsubsync alignment), Convention: autosubsync transform-cache tied to retimed path, Gotcha: conditional profiles need profile-restore=copy-equal, dynamic-crop.lua (CUDA sidecar backend), dynamic-crop-legacy.lua (cropdetect fallback) (+31 more)

### Community 8 - "memo.lua / show_history()"
Cohesion: 0.08
Nodes (26): ass_clean(), bind_keys(), close_menu(), draw_menu(), file_load(), get_full_path(), has_protocol(), memo_close() (+18 more)

### Community 9 - "mp.get_property_native"
Cohesion: 0.05
Nodes (62): mp.add_periodic_timer(), mp.add_timeout(), mp.get_property_native(), mp.set_property_bool(), delete_watch_later(), pause_timer_while_paused(), save(), save_if_pause() (+54 more)

### Community 10 - "inputevent.lua"
Cohesion: 0.09
Nodes (14): bind(), bind_from_conf(), bind_from_json(), bind_from_options_configs(), command(), command_invert(), command_split(), debounce() (+6 more)

### Community 11 - "utils.parse_json"
Cohesion: 0.07
Nodes (41): build_curl_args(), is_rate_limited(), M.request_async(), M.request_async_json(), parse_curl_output(), parse_json_response(), mp.create_osd_overlay(), utils.parse_json() (+33 more)

### Community 12 - "mp.command_native"
Cohesion: 0.09
Nodes (42): mp.command_native(), mp.command_native_async(), clean_chapters(), clear_category_bindings(), create_chapter(), fade_audio(), file_exists(), file_loaded() (+34 more)

### Community 13 - "cursor.lua"
Cohesion: 0.08
Nodes (15): mp.get_time(), Controls:register_badge_updater(), Element:register_disposer(), Menu:activate_menu(), Menu:reset_navigation(), Speed:handle_cursor_down(), Timeline:on_global_mouse_move(), cursor:collides_with() (+7 more)

### Community 14 - "menu.lua"
Cohesion: 0.12
Nodes (13): add_final_mapping(), apply_builtin_groups(), contains_control(), get_selected_group_names(), install_bindings(), is_ascii(), load_map_file(), load_user_maps() (+5 more)

### Community 18 - "lib/utils.lua"
Cohesion: 0.13
Nodes (34): Timeline:init(), cursor:direction_to_rectangle_distance(), create_track_loader_menu_opener(), open_file_navigation_menu(), open_open_file_menu(), itable_map(), call_ziggy(), delete_file() (+26 more)

### Community 19 - "std.lua"
Cohesion: 0.07
Nodes (23): Element:has_keybindings(), Element:remove_key_bindings(), Menu:enable_key_bindings(), Menu:update(), cursor:clear_zones(), get_languages(), CircularBuffer:clear(), comma_split() (+15 more)

### Community 20 - "request_render"
Cohesion: 0.12
Nodes (14): Elements:remove(), Menu:activate_index(), Menu:deactivate_items(), Menu:handle_cursor_up(), Menu:navigate_action(), Menu:on_global_mouse_move(), Menu:search_trigger(), Menu:select_action() (+6 more)

### Community 21 - "subtitle.lua / AbstractSubtitle:parse_file…"
Cohesion: 0.10
Nodes (4): AbstractSubtitle:parse_file(), SRT.entry(), SRT:populate(), trim()

### Community 22 - "TopBar.lua"
Cohesion: 0.11
Nodes (4): expand_template(), TopBar:add_template_listener(), TopBar:register_observers(), get_expansion_props()

### Community 23 - "media.lua"
Cohesion: 0.13
Nodes (9): best_type_from_counts(), M.classify_content_type(), M.clean_title(), M.extract_series_info(), M.normalize_path_key(), M.normalize_stem_key(), M.path_title_candidates(), M.release_head() (+1 more)

### Community 24 - "table_assign"
Cohesion: 0.22
Nodes (9): Element:init(), ManagedButton:init(), Menu:scroll_to(), Menu:update_items(), itable_join(), table_assign(), table_copy(), execute_command() (+1 more)

### Community 25 - "Element.lua"
Cohesion: 0.10
Nodes (5): Element:flash(), Element:register_mp_event(), Element:trigger(), Element:tween(), tween()

### Community 26 - "Updater.lua"
Cohesion: 0.15
Nodes (11): cleanup_output(), Updater:append_output(), Updater:check(), Updater:display_error(), Updater:init(), Updater:open_changelog(), Updater:select_next_button(), Updater:select_prev_button() (+3 more)

### Community 28 - "store.lua / M.get()"
Cohesion: 0.29
Nodes (15): exit_ok(), have_bin(), log(), M.del(), M.get(), M.init(), M.purge_older(), M.put() (+7 more)

### Community 29 - "mp.set_property_native"
Cohesion: 0.09
Nodes (18): mp.set_property_native(), Menu:destroy(), Menu:init(), Menu:move_selected_item_by(), Menu:set_scroll_to(), Menu:update_dimensions(), Speed:handle_cursor_up(), Speed:handle_wheel_down() (+10 more)

### Community 30 - "fzy.lua / compute()"
Cohesion: 0.20
Nodes (8): compute(), fzy.filter(), fzy.has_match(), fzy.positions(), fzy.score(), is_lower(), is_upper(), precompute_bonus()

### Community 31 - "t"
Cohesion: 0.13
Nodes (27): mp.register_event(), Controls:init_options(), Elements:flash(), TopBar:update_render_titles(), t(), create_select_tracklist_type_menu_opener(), create_self_updating_menu_opener(), get_all_user_bindings() (+19 more)

### Community 32 - "text.lua"
Cohesion: 0.07
Nodes (39): Element:update_proximity(), Menu:search_internal(), Menu:update_content_dimensions(), search_items(), Timeline:render(), TopBar:render(), Updater:render(), ass_mt.opacity() (+31 more)

### Community 33 - "clipshot.lua"
Cohesion: 0.60
Nodes (5): base_dir(), build_cmd(), clipshot(), pid(), unique_file()

### Community 34 - "uosc/main.lua"
Cohesion: 0.18
Nodes (10): timestamp_zero_rep_clear_cache(), render(), create_state_setter(), handle_options(), set_state(), update_display_dimensions(), update_duration(), update_fullormaxed() (+2 more)

### Community 35 - "subtitle_api.lua / do_fetch()"
Cohesion: 0.26
Nodes (8): build_query(), do_fetch(), log(), M.candidates(), M.fetch(), M.url_encode(), parse_headers(), remove_quiet()

### Community 36 - "tvdb.lua / test_tvdb.lua"
Cohesion: 0.26
Nodes (8): auth_headers(), log(), M.login(), M.resolve_absolute(), M.search_series(), default_episodes_page(), default_login_response(), setup_provider()

### Community 37 - "localdb.lua / M.find_episode_subs()"
Cohesion: 0.30
Nodes (9): log(), M.find_episode_subs(), M.find_movie_subs(), M.init(), M.slug_candidates(), num(), query(), slugify() (+1 more)

### Community 38 - "timing_ref.py"
Cohesion: 0.12
Nodes (46): affine_from_matches(), apply_affine(), apply_oracle(), apply_times(), asr_cues(), build_oracle(), Cue, detect_src_lang() (+38 more)

### Community 40 - "CycleButton:init"
Cohesion: 0.50
Nodes (3): CycleButton:init(), yes_no_to_boolean(), trim()

### Community 42 - "cursor:trigger"
Cohesion: 0.67
Nodes (3): cursor:trigger(), find_active_keybindings(), point_collides_with()

### Community 43 - "run.lua / _fmt()"
Cohesion: 0.29
Nodes (5): _fmt(), harness.eq(), harness.eq_n(), harness.same(), _same()

### Community 46 - "no-index-seek.lua"
Cohesion: 0.27
Nodes (12): best_jump_point(), djb2_hex(), do_seek(), fast_seek_to(), format_time(), index_path(), load_index(), make_abs_seek() (+4 more)

### Community 49 - "zstd.lua"
Cohesion: 0.20
Nodes (7): copy_beside(), M.activate(), M.is_beside_video(), djb2_hex(), file_info_of(), fingerprint(), hot_matches_source()

### Community 52 - "itable_find() / Menu:select_by_offset()"
Cohesion: 0.25
Nodes (8): Elements:toggle(), Menu:activate_one_value(), Menu:activate_value(), Menu:delete_value(), Menu:select_by_offset(), Menu:select_value(), TopBar:select_current_chapter(), itable_find()

### Community 54 - "uosc_picker.lua / M.format_item()"
Cohesion: 0.60
Nodes (3): format_score(), M.build_menu(), M.format_item()

### Community 63 - "sub-lang-filter.lua"
Cohesion: 0.38
Nodes (11): announce(), base(), build_allowed(), cycle(), expand(), label(), norm(), on_track_list() (+3 more)

### Community 81 - "curl_secrets.lua"
Cohesion: 0.47
Nodes (3): M.protect(), M.protect_command(), quote()

### Community 82 - "compare_from_history.py"
Cohesion: 0.53
Nodes (4): find_ar_sub(), history_videos(), main(), Path

### Community 84 - "AGENTS.md"
Cohesion: 0.40
Nodes (3): Non-negotiables, Pipeline (see CLAUDE.md for detail), Quick commands

### Community 85 - "GEMINI.md"
Cohesion: 0.40
Nodes (3): Non-negotiables, Pipeline (see CLAUDE.md for detail), Quick commands

## Knowledge Gaps
- **62 isolated node(s):** `width`, `height`, `x`, `y`, `crop` (+57 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **14 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `mp.get_property_native()` connect `mp.get_property_native` to `autosubsync.lua`, `ar_subs.lua`, `mp.commandv() / mp.get_property_native()`, `dynamic-crop.lua`, `memo.lua / show_history()`, `inputevent.lua`, `utils.parse_json`, `mp.command_native`, `cursor:trigger`, `no-index-seek.lua`, `lib/utils.lua`, `std.lua`, `t`, `sub-lang-filter.lua`?**
  _High betweenness centrality (0.106) - this node is a cross-community bridge._
- **Why does `mp.command_native()` connect `mp.command_native` to `autosubsync.lua`, `ar_subs.lua`, `dynamic-crop.lua`, `subdl.lua`, `Menu.lua`, `mp.get_property_native`, `inputevent.lua`, `utils.parse_json`, `lib/utils.lua`, `TopBar.lua`, `table_assign`, `Updater.lua`, `t`?**
  _High betweenness centrality (0.068) - this node is a cross-community bridge._
- **Why does `request_render()` connect `request_render` to `text.lua`, `uosc/main.lua`, `Menu.lua`, `memo.lua / show_history()`, `mp.get_property_native`, `cursor.lua`, `Controls.lua`, `Timeline.lua`, `lib/utils.lua`, `itable_find() / Menu:select_by_offset()`, `table_assign`, `Element.lua`, `Updater.lua`, `Elements.lua`, `mp.set_property_native`, `t`?**
  _High betweenness centrality (0.063) - this node is a cross-community bridge._
- **Are the 56 inferred relationships involving `mp.get_property_native()` (e.g. with `apply_crop()` and `filter_state()`) actually correct?**
  _`mp.get_property_native()` has 56 INFERRED edges - model-reasoned connections that need verification._
- **Are the 52 inferred relationships involving `mp.get_property()` (e.g. with `apply_crop()` and `on_start()`) actually correct?**
  _`mp.get_property()` has 52 INFERRED edges - model-reasoned connections that need verification._
- **Are the 38 inferred relationships involving `request_render()` (e.g. with `Controls:update_dimensions()` and `Element:flash()`) actually correct?**
  _`request_render()` has 38 INFERRED edges - model-reasoned connections that need verification._
- **Are the 36 inferred relationships involving `mp.osd_message()` (e.g. with `on_toggle()` and `switch_hwdec()`) actually correct?**
  _`mp.osd_message()` has 36 INFERRED edges - model-reasoned connections that need verification._