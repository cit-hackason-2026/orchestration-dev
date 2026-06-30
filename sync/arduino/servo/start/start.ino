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

  // ロードセルに小物が置かれているときはサーボモーターを回転させ，小物が取り除かれたら回転を止める
  if (weight > THRESHOLD) {
    servo.writeMicroseconds(MOVE_US);
  } else {
    servo.writeMicroseconds(STOP_US);
  }
}