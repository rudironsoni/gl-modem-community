module.exports=({
	name: "esim",
	template: '<div class="esim-management-wrapper">' +
		'<div class="esim-info-wrapper"><ul class="info-main">' +
		'<li class="title-li">{{ titleStatus }}</li>' +
		'<li><span>EID</span><span>{{ esimStatusInfo.eid || "-" }}</span></li>' +
		'<li><span>ICCID</span><span>{{ esimStatusInfo.iccid || "-" }}</span></li>' +
		'<li><span>IMSI</span><span>{{ esimStatusInfo.imsi || "-" }}</span></li>' +
		'<li><span>{{ labelOs }}</span><span>{{ esimStatusInfo.cos || "-" }}</span></li>' +
		'<li><span>{{ labelStorage }}</span><span>{{ esimStatusInfo.esimStorage || "-" }}</span></li>' +
		'<li><span>{{ labelCount }}</span><span>{{ esimStatusInfo.esimProfileNumber }}</span></li>' +
		'</ul></div>' +
		'<div class="esim-profile-wrapper">' +
		'<div class="profile-header"><div class="profile-title">{{ titleList }}</div></div>' +
		'<div class="profile-main" v-for="item in profileList" :key="item.iccid">' +
		'<span class="badge" :class="{ \'is-online\': item.state === 1 }"></span> ' +
		'<span>{{ item.name || item.iccid }}</span>' +
		'<div class="btns">' +
		'<button class="btn-item" @click="enable(item.iccid)">Enable</button>' +
		'<button class="btn-item" @click="disable(item.iccid)">Disable</button>' +
		'<button class="btn-item" @click="remove(item.iccid)">Delete</button>' +
		'</div></div></div>' +
		'<div class="add-profile-btn" @click="showAdd = !showAdd">' +
		'<span class="iconfont icon-plus"></span> {{ labelAdd }}' +
		'</div>' +
		'<div v-if="showAdd">' +
		'<input v-model="activationCode" :placeholder="labelCode" />' +
		'<input v-model="confirmationCode" :placeholder="labelConfirm" />' +
		'<button class="btn-item" @click="install">Install</button>' +
		'</div>' +
		'<div class="export-log-btn"><span @click="exportLog">{{ labelLog }}</span></div>' +
		'<pre class="esim-install-dialog" v-if="logText">{{ logText }}</pre>' +
		'</div>',
	data: function () {
		return {
			esimStatusInfo: { eid: "", iccid: "", imsi: "", cos: "", esimStorage: "", esimProfileNumber: 0 },
			profileList: [],
			showAdd: false,
			activationCode: "",
			confirmationCode: "",
			logText: ""
		};
	},
	computed: {
		titleStatus: function () { return this.t("esim.current_esim_status_title", "Current eSIM Status"); },
		titleList: function () { return this.t("esim.esim_profile_list_title", "eSIM Profile List"); },
		labelOs: function () { return this.t("esim.esim_os_version", "eSIM OS Version"); },
		labelStorage: function () { return this.t("esim.esim_storage", "eSIM Storage"); },
		labelCount: function () { return this.t("esim.esim_profile_number", "eSIM Profile Number"); },
		labelAdd: function () { return this.t("esim.add_esim_profile", "Add eSIM Profile"); },
		labelCode: function () { return this.t("esim.activation_code", "Activation Code"); },
		labelConfirm: function () { return this.t("esim.confirmation_code", "Confirmation code"); },
		labelLog: function () { return this.t("esim.export_support_log", "Export Log For Support"); }
	},
	created: function () { this.refresh(); },
	mounted: function () {
		if (document.getElementById("gmc-esim-style")) return;
		var style = document.createElement("style");
		style.id = "gmc-esim-style";
		style.textContent =
			".esim-profile-wrapper .profile-header{display:flex;align-items:center;padding:0 10px;min-height:40px;border-radius:5px;background-color:var(--background-subtitle)}" +
			".esim-profile-wrapper .profile-header .profile-title{font-size:14px;color:var(--text-subtitle);font-weight:700}" +
			".esim-profile-wrapper .profile-main .badge{display:inline-block;width:8px;height:8px;border-radius:50%;background-color:var(--background-badge)}" +
			".esim-profile-wrapper .profile-main .badge.is-online{background-color:var(--success)}" +
			".esim-profile-wrapper .profile-main .btns{justify-content:flex-start;display:flex;gap:8px;margin:8px 0 16px}" +
			".esim-profile-wrapper .profile-main .btns .btn-item{min-width:90px;height:36px}" +
			".esim-info-wrapper .info-main>li{display:flex;align-items:center;justify-content:space-between;min-height:59px}" +
			".esim-info-wrapper .info-main>li:not(.title-li){padding:14px 15px;border-bottom:1px solid var(--divider)}" +
			".esim-info-wrapper .info-main>li:last-child{border:none}" +
			".esim-info-wrapper .info-main>li.title-li{padding:0 10px;min-height:40px;color:var(--text-subtitle);font-size:14px;font-weight:700;border-radius:5px;background-color:var(--background-subtitle)}" +
			".esim-info-wrapper .info-main>li>span:first-child{flex:1;margin-right:10px;color:var(--text-weak)}" +
			".esim-info-wrapper .info-main>li>span:last-child{width:60%;min-width:160px;color:var(--text-regular);text-align:right;word-break:break-all}" +
			".esim-management-wrapper .add-profile-btn{margin:24px 0;height:48px;border:1px dashed var(--text-hint);border-radius:5px;display:flex;justify-content:center;align-items:center;color:var(--primary);cursor:pointer}" +
			".esim-management-wrapper .export-log-btn{height:48px;display:flex;justify-content:flex-end}" +
			".esim-management-wrapper .export-log-btn span{cursor:pointer;color:var(--primary)}";
		document.head.appendChild(style);
	},
	methods: {
		t: function (key, fallback) {
			try {
				if (this.$t) return this.$t(key);
			} catch (e) {}
			return fallback;
		},
		sdk: function (method, extra) {
			var body = Object.assign({ txId: String(Date.now()), method: method, env: 1 }, extra || {});
			var req = window.$axios ? window.$axios.create() : null;
			if (req) return req.post("/sdk/v1", body);
			return fetch("/sdk/v1", {
				method: "POST",
				headers: { "Content-Type": "application/json" },
				body: JSON.stringify(body)
			}).then(function (r) { return r.json(); }).then(function (d) { return { data: d }; });
		},
		refresh: function () {
			var self = this;
			this.sdk("status").then(function (res) {
				var data = (res && res.data && res.data.data) || (res && res.data) || {};
				var env = data.env || {};
				self.esimStatusInfo.eid = data.eid || "";
				self.esimStatusInfo.iccid = env.iccid || "";
				self.esimStatusInfo.imsi = env.imsi || "";
				self.esimStatusInfo.esimProfileNumber = (data.profile_list || []).length;
				self.profileList = data.profile_list || [];
			});
			this.sdk("info2").then(function (res) {
				var data = (res && res.data && res.data.data) || (res && res.data) || {};
				try {
					var mem = JSON.parse(data.extCardResource || "{}").non_volatile_mem || 0;
					self.esimStatusInfo.esimStorage = Math.ceil(mem / 1024) + "KB/360KB";
				} catch (e) {}
			});
			this.sdk("GetEIDInfo", { params: { eid: this.esimStatusInfo.eid }, remote: true }).then(function (res) {
				var data = (res && res.data && res.data.data) || (res && res.data) || {};
				self.esimStatusInfo.cos = (data.dev_info && data.dev_info.cos) || "";
			});
		},
		enable: function (iccid) { var self = this; this.sdk("enable", { iccid: iccid }).then(function () { self.refresh(); }); },
		disable: function (iccid) { var self = this; this.sdk("disable", { iccid: iccid }).then(function () { self.refresh(); }); },
		remove: function (iccid) { var self = this; this.sdk("delete", { iccid: iccid }).then(function () { self.refresh(); }); },
		install: function () {
			var self = this;
			this.sdk("install", {
				activationCode: this.activationCode,
				confirmationCode: this.confirmationCode
			}).then(function () { self.showAdd = false; self.activationCode = ""; self.confirmationCode = ""; self.refresh(); });
		},
		exportLog: function () {
			var self = this;
			this.sdk("log").then(function (res) { self.logText = (res && res.data) || ""; });
		}
	}
});
