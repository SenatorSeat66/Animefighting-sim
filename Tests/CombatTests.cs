using System;
using ShadowFighting;
static class CombatTests
{
 static int passed;
 static void Check(bool condition,string name) { if(!condition)throw new Exception(name);Console.WriteLine("PASS "+name);passed++; }
 static Duel Setup() { var d=new Duel(0);d.Player.X=-1;d.Enemy.X=1;d.Cooldown=99;return d; }
 static void Advance(Duel d,float duration) { for(int i=0;i<(int)(duration*120);i++)d.Tick(1f/120,0); }
 static void EnemyMove(Duel d,MoveKind kind) { d.Enemy.Move=new Move(kind,.12f,3,20,25); }
 static void Main()
 {
  var d=Setup();EnemyMove(d,MoveKind.Slash);d.Guard(true);Advance(d,.14f);
  Check(d.LastEvent==CombatEvent.Deflect && d.Player.Health==100 && d.Enemy.Posture>0,"timely guard deflects and damages attacker posture");
  d=Setup();d.Guard(true);Advance(d,.4f);EnemyMove(d,MoveKind.Slash);Advance(d,.14f);
  Check(d.LastEvent==CombatEvent.Block && d.Player.Health==100 && d.Player.Posture>0,"held guard blocks with posture cost");
  d=Setup();EnemyMove(d,MoveKind.Sweep);d.Guard(true);Advance(d,.14f);
  Check(d.Player.Health==80,"sweep bypasses held guard");
  d=Setup();EnemyMove(d,MoveKind.Sweep);d.Jump();Advance(d,.14f);
  Check(d.Player.Health==100 && d.Enemy.Posture>0,"jump counters sweep");
  d=Setup();EnemyMove(d,MoveKind.Thrust);d.Step();Advance(d,.14f);
  Check(d.Player.Health==100 && d.Enemy.StunLeft>0,"forward step counters thrust");
  d=Setup();d.Enemy.Posture=90;d.Attack();Advance(d,.25f);
  Check(d.Enemy.BreakLeft>0,"blocked pressure can break guard");Advance(d,.6f);d.Attack();
  Check(d.Won && d.LastEvent==CombatEvent.Finish,"nearby strike finishes broken opponent");
  d=Setup();d.Player.X=-5;d.Enemy.X=5;EnemyMove(d,MoveKind.Slash);Advance(d,.2f);
  Check(d.Player.Health==100,"out-of-range attack cannot damage");
  d=Setup();d.Enemy.Health=0;float x=d.Player.X;d.Tick(.05f,1);
  Check(d.Player.X==x,"ended duel freezes simulation");
  d=Setup();d.Fire();float cooldown=d.FireCooldown;d.Fire();Check(d.FireCooldown==cooldown,"fire cooldown prevents repeated casting");
  d=Setup();d.Enemy.Move=new Move(MoveKind.Slash,.7f,3,20,25);d.Attack();Advance(d,.3f);
  Check(d.Enemy.Move!=null && d.Enemy.Health<100,"committed enemy windup survives strike pressure");
  Console.WriteLine(passed+" checks passed");
 }
}
