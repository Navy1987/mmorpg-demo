﻿using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class CharacterUI : MonoBehaviour {
	public Slider role_hpbar;
	public Text role_name;
	public float role_hpbar_offset;
	public float role_name_offset;
	public float role_ui_scale_frac = 2.0f;
	public float role_ui_scale_min = 0.5f;
	public float role_ui_scale_max = 1.0f;

	public float HP {
		set {
			role_hpbar.value = value;
		}
	}
	public string Name {
		get { return role_name.text; }
		set { role_name.text = value; }
	}
	private void checkSee(GameObject obj, Vector3 pos, float scale) {
		scale = Mathf.Clamp(scale, role_ui_scale_min, role_ui_scale_max);
		obj.transform.position = pos;
		obj.transform.localScale = scale * Vector3.one;
	}
	public void OnUpdate() {
		var uicamera = Module.Camera.ui;
		var maincamera = Module.Camera.main;
		if (uicamera == null)
			return ;
		float scale = role_ui_scale_frac / Vector3.Distance(transform.position, maincamera.transform.position);
		var pos = transform.position;
		pos.y += role_hpbar_offset;
		var hp_uipos = maincamera.WorldToScreenPoint(pos);
		hp_uipos = uicamera.ScreenToWorldPoint(hp_uipos);
		checkSee(role_hpbar.gameObject, hp_uipos, scale);
		pos.y += role_name_offset;
		var name_uipos = maincamera.WorldToScreenPoint(pos);
		name_uipos = uicamera.ScreenToWorldPoint(name_uipos);
		checkSee(role_name.gameObject, name_uipos, scale);
	}
}
