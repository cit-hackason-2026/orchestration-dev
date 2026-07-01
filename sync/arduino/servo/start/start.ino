#include "HX711.h" // 作者がBogdan NeculaのHX711系のライブラリをインストールする必要がある
#include <Servo.h>

// ロードセルの設定
const int DT_PIN  = 3;
const int SCK_PIN = 2;
HX711 scale;

// サーボモーターの設定
Servo servo;
const int SERVO_PIN = 9;
const float THRESHOLD = 50.0;   // この重さ(g)を超えたら回す．実測値に合わせて変更する
int MOVE_US = 1480;   // 回転速度（BPMの変更に合わせて可変されるようにする）
const int STOP_US   = 1500;   // 停止

// サーボ1周にかかる時間（約2.2s）
// 測定方法：10回転分の時間を計測し，その平均（合計時間 ÷ 10）を1周の時間とした
// ※MOVE_US（回転速度）を変えると1周の時間も変わるので，そのときは測り直す
const int ROTATION_MS = 2200;

// 状態管理用フラグ
bool flag     = false;   // 現在の状態：閾値を超えていれば true
bool prevFlag = false;   // 前回ループの状態（切り替わりの検知に使う）

void setup() {
  Serial.begin(9600);

  scale.begin(DT_PIN, SCK_PIN);
  scale.set_scale(2280);  // キャリブレーションで設定した値，必要があれば変更を加える
  scale.tare();

  // 初期状態は停止させる
  servo.attach(SERVO_PIN);
  servo.writeMicroseconds(STOP_US);

  Serial.println("準備完了");
}

void loop() {
  float weight = scale.get_units(3);  // 3回平均で重さを取得

  // 荷重検知のテスト用のログ
  Serial.print("重さ: ");
  Serial.print(weight, 1);
  Serial.println(" g");

  // 閾値を超えているかどうかでフラグを切り替える
  if (weight > THRESHOLD) {
    flag = true;
  } else {
    flag = false;
  }

  // ---- フラグが切り替わった瞬間だけ処理する ----
  // （単純な if/else にすると物が乗っている間ずっと delay が走ってしまうため）

  // 立ち上がり：小物が置かれた（false → true）
  if (flag && !prevFlag) {
    servo.writeMicroseconds(MOVE_US);  // サーボ回転開始
    delay(ROTATION_MS);                // 1周（約2.2s）まわしてから輪唱スタート

    // ============================================================
    // ▼ 輪唱「開始」の処理をここに書く（担当：別の人）
    //   例）1声目の再生を始める など
    // ============================================================
  }

  // 立ち下がり：小物が取り除かれた（true → false）
  if (!flag && prevFlag) {
    servo.writeMicroseconds(STOP_US);  // サーボ停止

    // ============================================================
    // ▼ 輪唱「停止」の処理をここに書く（担当：別の人）
    //   例）全声部を止める など
    // ============================================================
  }

  // 今回の状態を保存（次ループで比較するため）
  prevFlag = flag;
}