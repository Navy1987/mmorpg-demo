﻿using System;
using System.Xml;
using System.IO;
using System.Reflection;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace DB {

public abstract class XmlLoad {
	public abstract void Load(string path);
}

public class XmlSet<T, K> : XmlLoad where T:new(){
	private Dictionary<K, T> pool = new Dictionary<K, T>();
	public T Get(K key) {
		if (pool.ContainsKey(key))
			return pool[key];
		return default(T);
	}

	public override void Load(string path) {
		XmlDocument doc = new XmlDocument();
		if (!System.IO.File.Exists(path))
			return ;
		doc.LoadXml(System.IO.File.ReadAllText(path));
		XmlNode root = doc.DocumentElement;
		for (int i = 0; i < root.ChildNodes.Count; i++) {
			var n = root.ChildNodes[i];
			T var = new T();
			FieldInfo[] fi = var.GetType().GetFields();
			for (int j = 0; j < fi.Length; j++) {
				var val = n.Attributes.GetNamedItem(fi[j].Name).Value;
				fi[j].SetValue(var, Convert.ChangeType(val, fi[j].FieldType));
				if (fi[j].Name == "Key")
					pool[(K)fi[j].GetValue(var)] = var;
			}
		}
	}
}


public class DB {
	public static XmlSet<LanguageItem, string> Language = new XmlSet<LanguageItem, string>();
	public static XmlSet<RoleLevelItem, int> RoleLevel = new XmlSet<RoleLevelItem, int>();

	public static void Load() {
		FieldInfo[] fi = typeof(DB).GetFields();
		Debug.Log("Load:"+  fi.Length);
		for (int j = 0; j < fi.Length; j++) {
			var name = fi[j].Name;
			XmlLoad obj = (XmlLoad)fi[j].GetValue(null);
			obj.Load(Tool.GetPath("DB/" + name + ".xml"));
		}
		Debug.Log("RoleLevel:" + RoleLevel.Get(1).Value);
	}
}}
