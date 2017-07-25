﻿using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.AI;

public class Shadow {
	public Vector3 pos;
	public Quaternion rot;
};
public class MoveDir {
	public Vector3 pos;
	public Vector3 dir;
};

[RequireComponent(typeof(Animator))]
[RequireComponent(typeof(Rigidbody))]
[RequireComponent(typeof(CapsuleCollider))]
[RequireComponent(typeof(NavMeshAgent))]
public class Character : MonoBehaviour {
	//component
	private Rigidbody RB;
	private Animator animator;
	private CharacterUI UI;
	//data
	private int uid = -1;
	private Shadow shadow = new Shadow();
	///////////////////shadow follow
	public void SetShadow(Vector3 pos, Quaternion rot) {
		shadow.pos = pos;
		shadow.rot = rot;
		transform.localRotation = shadow.rot;
	}

	bool SetRun(float z) {
		if (z > 0.0001f) {
			animator.SetBool("Run", true);
			animator.SetFloat("RunDir", 1.0f);
			return true;
		} else if (z < -0.0001f) {
			animator.SetBool("Run", true);
			animator.SetFloat("RunDir", -1.0f);
			return true;
		}
		animator.SetBool("Run", false);
		animator.SetFloat("RunDir", 0.0f);
		return false;
	}

	void FixedAnimator() {
		var delta = transform.position;
		delta.y = 0;
		delta = shadow.pos - delta;
		var dir = transform.InverseTransformDirection(delta);
		SetRun(dir.z);
	}
	///////////property
	public string Name {
		get { return UI.Name; }
		set { UI.Name = value; }
	}
	private int hp;
	public int HP {
		get { return hp; }
		set {
			int delta = hp;
			hp = value;
			delta = hp - delta;
			if (delta == 0.0f)
				return ;
			var xml = DB.DB.RoleLevel.Get(Module.Role.Basic.level);
			float HP = xml.Hp;
			float rat = hp / HP;
			Debug.Log("[HP]Uid:" + uid + "delta:" + delta + ":value:" + value + ":max:" + rat);
			UI.HP = rat;
			var pos = transform.position;
			pos.y += GameConfig.role_ui_high;
			var obj = Tool.InstancePrefab("UI/FlyNum", pos, Quaternion.identity);
			var fly = obj.GetComponent<FlyNum>();
			fly.Fly(delta, pos, 3);
		}
	}
	public int UID {
		get { return uid; }
		set { uid = value; }
	}
	public Vector3 Position {
		get { return transform.position; }
	}

	////////////Simulator
	enum MoveType {
		MOVE_NONE = 0,
		MOVE_DIR = 1,
		MOVE_POINT = 2,
	};
	private MoveType move_type = MoveType.MOVE_NONE;
	private MoveDir move_dir;
	private UnityEngine.AI.NavMeshAgent agent;
	public void MoveDir(Vector3 pos, Vector3 dir) {

	}

	public void MovePoint(Vector3 src, Vector3 dst, uint movetime) {
		float dist = Vector3.Distance(src, dst);
		uint reachtime = (uint)(dist / GameConfig.main_runspeed * 1000) + movetime;
		int havetime = (int)(reachtime - Module.Control.clock);
		if (havetime < 0)
			havetime = 1;
		float ndist = Vector3.Distance(transform.position, dst);
		float speed = ndist / ((float)havetime / 1000);
		Debug.Log("Speed" + dist + ":" + ndist + ":" + havetime + ":" + speed);
		agent.SetDestination(dst);
		agent.speed = speed;
		move_type = MoveType.MOVE_POINT;
	}

	private void UpdateMoveDir() {
		if (move_type != MoveType.MOVE_DIR)
			return ;

	}
	private void UpdateMovePoint() {
		if (move_type != MoveType.MOVE_POINT)
			return ;
		SetShadow(agent.nextPosition, transform.localRotation);
	}

	private void MoveUpdate() {
		UpdateMoveDir();
		UpdateMovePoint();
	}

	////////////iherit
	void Awake() {
		RB = GetComponent<Rigidbody>();
		animator = GetComponent<Animator>();
		RB.constraints =
			RigidbodyConstraints.FreezeRotationX |
			RigidbodyConstraints.FreezeRotationY |
			RigidbodyConstraints.FreezeRotationZ;
		shadow.pos = transform.position;
		shadow.rot = transform.localRotation;
		UI = GetComponent<CharacterUI>();
		agent = GetComponent<UnityEngine.AI.NavMeshAgent>();
		agent.updatePosition = false;
	}

	void Start() {
		shadow.pos = transform.position;
		shadow.rot = transform.localRotation;
	}

	void OnAnimatorMove()
	{
		var src = transform.position;
		src.y = 0;
		var pos = Vector3.Slerp(src, shadow.pos, 0.5f);
		pos.y = transform.position.y;
		transform.position = pos;
	}

	void FixedUpdate() {
		FixedAnimator();
		MoveUpdate();
		if (UI != null)
			UI.OnUpdate();
	}
}
