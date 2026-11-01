class_name Radio
extends RefCounted
## Reactive radio lines: [speaker, English (spoken + subtitle), Korean (subtitle translation)].
## {n} is filled by Sim.say_key(). Speakers: HQ, Squad Leader, Comms, and the station roles in ROLES.
## Spoken audio is pre-rendered per (speaker, text piece): run tools/gen_voice.py after editing any line.

const ROLES := {"Radar Operator": "radar", "EO Operator": "eo", "Fire Control": "fire"}

# Words HQ reads out for a target (index = describe() bucket).
const ALT_EN := ["on the deck", "low altitude", "medium altitude", "high altitude"]
const ALT_KO := ["초저고도", "저고도", "중고도", "고고도"]
const SPD_EN := ["fast", "medium speed", "slow"]
const SPD_KO := ["고속", "중속", "저속"]
const HDG_EN := ["inbound to your position", "outbound", "crossing"]
const HDG_KO := ["우리 쪽으로 접근 중", "이탈 중", "횡단 중"]

const TEST := ["HQ", "Radio check, how do you read?", "무전 점검, 감도 어떤가?"]

const LINES := {
	"track_new": [["Radar Operator", "Track started, number {n}. Maintaining.", "트랙 시작, 번호 {n}. 계속 추적한다."],
		["Squad Leader", "Good. Don't lose that contact.", "좋아, 그 표적 놓치지 마라."]],
	"track_lost": [["Radar Operator", "Lost track {n}! Reacquiring.", "트랙 {n} 소실! 재탐색한다."],
		["HQ", "Track {n} dropped. Reacquire.", "트랙 {n} 끊겼다. 다시 확보하라."]],
	"report_ok": [["HQ", "Report copied. Matches our picture.", "보고 수신. 우리 정보와 일치한다."],
		["HQ", "Roger. Continue monitoring.", "확인했다. 계속 감시하라."]],
	"report_bad": [["HQ", "Negative. That does not match our picture. Verify.", "아니다. 우리 정보와 다르다. 재확인하라."],
		["Squad Leader", "Too hasty. Check again.", "성급했군. 다시 확인해."]],
	"hostile_auth": [["HQ", "Contact declared hostile. You are cleared to engage.", "적기로 선언한다. 교전 허가."],
		["HQ", "Identification confirmed. Hostile, weapons free.", "식별 확인. 적 표적, 무기 자유."]],
	"launch": [["Fire Control", "Missile away! In flight.", "발사! 미사일 비행 중."],
		["Squad Leader", "Launch confirmed. Watch for impact.", "발사 확인. 명중을 지켜봐라."]],
	"kill_h": [["HQ", "Splash one hostile. Good work.", "적기 격추 확인. 잘했다."],
		["Fire Control", "Hit! Target destroyed!", "명중! 표적 소멸!"],
		["Squad Leader", "One down. Ready for the next.", "한 대 잡았다. 다음 표적 준비."]],
	"kill_f": [["HQ", "That was a friendly! Cease fire! What have you done?", "아군기다! 사격 중지! 무슨 짓이야!"]],
	"kill_c": [["HQ", "Civilian aircraft hit! Cease fire immediately!", "민항기 피격! 즉시 사격 중지!"]],
	"kill_f_w": [["HQ", "You knew that was a friendly and fired anyway! This goes to command!", "아군인 걸 알면서 쐈다! 지휘부에 보고하겠다!"]],
	"kill_c_w": [["HQ", "You fired on a civilian aircraft despite the warning! Command will open an investigation!", "경고를 무시하고 민항기를 쐈다! 지휘부가 조사에 착수할 것이다!"]],
	"kill_b_w": [["Squad Leader", "You knew it was birds. That was a wasted missile.", "새라는 걸 알면서 쐈군. 미사일 낭비다."]],
	"warn_friend": [["HQ", "Check fire, check fire! That track is squawking friendly!", "사격 중지, 사격 중지! 그 트랙은 아군 응답 중이다!"],
		["HQ", "Early warning relay: that contact is a friendly aircraft. Do not engage!", "조기경보 정보: 해당 표적은 아군기다. 교전하지 마라!"]],
	"warn_civil": [["HQ", "Negative, negative! That track is a civil airliner! Do not engage!", "안 된다! 그 트랙은 민항기다! 교전하지 마라!"],
		["HQ", "Early warning relay: civil transponder on that contact. Hold fire!", "조기경보 정보: 해당 표적은 민간 응답기를 켰다. 사격 중지!"]],
	"warn_briefed": [["HQ", "That is the aircraft we briefed you on. Hold fire!", "그 표적은 브리핑했던 기체다. 사격 중지!"]],
	"kill_b": [["Squad Leader", "It was a flock of birds. Wasted a missile.", "새 떼였다. 미사일만 낭비했군."]],
	"miss": [["Fire Control", "Missed! Preparing to re-engage.", "빗나갔다! 재교전 준비."],
		["HQ", "Intercept failed. Re-engage at once.", "요격 실패. 즉시 재교전하라."]],
	"terrain": [["Fire Control", "Missile hit the terrain. That contact is hugging the ground.", "미사일이 지형에 충돌했다. 저고도 표적이다."]],
	"site_hit": [["HQ", "We have a hit on your site! Report damage!", "피격 확인! 피해 상황 보고하라!"],
		["Squad Leader", "Direct hit! Everybody hold on!", "직격이다! 전원 버텨!"]],
	"low_ammo": [["Fire Control", "Only {n} missiles left. Make them count.", "잔탄 {n}발. 신중하게 쏴라."]],
	"no_ammo": [["Fire Control", "Magazine empty! Requesting resupply.", "탄 소진! 지원을 요청한다."]],
	"iff_friend": [["Radar Operator", "IFF reply. Friendly code.", "IFF 응답. 아군 코드다."]],
	"iff_civil": [["Radar Operator", "IFF reply. Civil code.", "IFF 응답. 민간 코드다."]],
	"iff_none": [["Radar Operator", "No IFF reply. Unable to identify.", "IFF 무응답. 식별 불가."]],
	"lock": [["EO Operator", "Lock on.", "락온 완료."]],
	"lock_lost": [["EO Operator", "Lock lost!", "락온 상실!"]],
	"lrf": [["EO Operator", "Laser range {n} meters.", "레이저 거리 {n}미터."]],
	"ducting": [["Radar Operator", "Ground returns beyond the horizon. Atmospheric ducting. Watch for low flyers.", "지평선 너머 지상 반사파가 들어온다. 대기 덕트 현상이다. 저고도 표적 주의."]],
	"rain": [["Radar Operator", "Rain echoes are covering the scope. Trying the rain filter.", "강우 에코가 화면을 덮는다. 레인 필터를 써 보겠다."]],
	"won": [["HQ", "Mission complete. Well done.", "임무 완료. 수고했다."]],
	"lost": [["HQ", "Mission failed. Stand down.", "임무 실패. 상황 종료."]],
}

const AMBIENT := [
	["Comms", "HQ, Sentinel. Comms check, signal strong.", "HQ, 센티넬. 통신 점검, 감도 양호."],
	["HQ", "All stations, weather is clear. Maintain vigilance.", "전 부대, 현재 기상 양호. 경계 유지."],
	["Squad Leader", "Did anyone check the generator fuel?", "발전기 연료 확인했나?"],
	["EO Operator", "Dust on the lens. Cleaning it while I scan.", "렌즈에 먼지가 꼈다. 닦으면서 보겠다."],
	["Fire Control", "Launcher status normal.", "발사대 상태 정상."],
	["Squad Leader", "One hour to shift change. Stay sharp.", "교대까지 한 시간이다. 집중 풀지 마라."],
	["Radar Operator", "A lot of ground clutter today.", "오늘은 지상 반사파가 꽤 많다."],
	["HQ", "Neighbouring unit reports an unknown contact to the west. Keep watching.", "인접 부대, 서쪽 방면 미확인 신호 접촉. 계속 감시."],
	["Comms", "Sergeant, the supply truck arrives in an hour.", "분대장님, 보급 차량이 한 시간 뒤 도착한답니다."],
	["Squad Leader", "No time for coffee. Eyes on the scope.", "커피 마실 시간은 없다. 화면 계속 봐."],
]

const WEATHER_LINES := {
	"Rain": ["HQ", "Rain in your sector. Expect radar attenuation and weather clutter.", "현재 강우 중. 레이더 감쇠와 비구름 에코에 유의하라."],
	"Storm": ["HQ", "Thunderstorm warning. Expect heavy radar degradation.", "뇌우 경보. 레이더 영상 열화가 예상된다."],
	"Fog": ["HQ", "Dense fog. Optical visibility is severely reduced.", "짙은 안개. 광학 장비 시정이 크게 떨어진다."],
}


static func pick(key: String, rng: RandomNumberGenerator) -> Array:
	var opts: Array = LINES[key]
	return opts[rng.randi() % opts.size()]


## Every [speaker, template] pair that can be spoken (used by tools/dump_voice.gd).
static func all_templates() -> Array:
	var out: Array = [[TEST[0], TEST[1]]]
	for key in LINES:
		for l in LINES[key]:
			out.append([l[0], l[1]])
	for l in AMBIENT:
		out.append([l[0], l[1]])
	for k in WEATHER_LINES:
		out.append([WEATHER_LINES[k][0], WEATHER_LINES[k][1]])
	return out
