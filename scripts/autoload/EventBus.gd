extends Node

# ============================================
# 全局事件总线 - 信号定义
# ============================================

# 玩家相关
signal xp_collected(amount: int)
signal level_up(level: int)
signal player_damaged(amount: float)  # 实际伤害值（减伤后），仅Player.take_damage发射
signal player_healed(amount: float)
signal player_died

# 敌人相关
signal enemy_killed(kind: StringName)
signal enemy_killed_detailed(position: Vector2, tier: StringName, combo_count: int, boss_phase: int, killing_weapon: StringName)
signal enemy_stunned(position: Vector2, duration: float)
signal enemy_frozen(position: Vector2, duration: float)  # 冰冻效果

# 游戏流程
signal game_over(win: bool)
signal game_started
signal game_paused
signal game_resumed
signal toggle_pause_requested
## 触屏 HUD「冲刺」按钮（无键盘时的空格等价）
signal dash_requested

# 升级系统
signal request_upgrade
signal upgrade_selected(upgrade_id: StringName)
signal upgrade_ui_state_changed(open: bool)
signal fusion_applied(fid: StringName)

# 伤害与特效
signal damage_number_spawned(position: Vector2, amount: float, is_critical: bool)
signal screen_shake(strength: float, duration: float)
signal screen_flash(color: Color, duration: float)
signal area_knockback(center: Vector2, radius: float, force: float)

# BOSS相关
signal boss_warning(strength: float, duration: float)
signal boss_telegraph(kind: int, origin: Vector2, dir: Vector2, radius: float, duration: float)
signal boss_defeated
signal boss_spawned

# 武器特效
signal lightning_strike(start: Vector2, end: Vector2)

# 音频
signal play_sfx(sound_name: StringName, position: Vector2)
signal play_music(track_name: StringName)
signal stop_music

# UI通知（第三参为 NotificationSystem 的 type：info/success/warning/error/item/achievement）
signal notification_shown(message: String, duration: float, notif_type: String)

## 画质档位变更（与后处理、粒子、雾等同步；商业向「一处改、全局跟」）
signal graphics_quality_changed(quality: int)
## 特效风格档位变更（竞技清晰/平衡默认/电影爽感）
signal vfx_profile_changed(profile: int)
## 高压性能保护开关变更
signal extreme_perf_guard_changed(enabled: bool)
## 开发期：请求重载武器反馈/音频配置卡（JSON）
signal weapon_cards_reload_requested

## 武器样式载体演出：kind 为 &"first_acquire" / &"level_up" 等；payload 含 prev_lv、new_lv、weapon_name、world_pos
signal weapon_presentation_requested(weapon_id: StringName, kind: StringName, payload: Dictionary)

# 技能“顶点”事件：某个被动/变异升到最大等级
signal skill_vertex_reached(kind: StringName, id: StringName)

# 战斗链路事件（技能生命周期）
signal skill_cast_start(skill_id: StringName, caster_id: int, cast_seq: int, timestamp_ms: int)
signal skill_active(skill_id: StringName, caster_id: int, cast_seq: int, frame_index: int, timestamp_ms: int)
signal skill_hit(skill_id: StringName, caster_id: int, target_id: int, cast_seq: int, damage_type: StringName, final_damage: float, is_critical: bool, timestamp_ms: int)
signal skill_end(skill_id: StringName, caster_id: int, cast_seq: int, reason: StringName, timestamp_ms: int)
