using System;
namespace ShadowFighting
{
    public enum MoveKind { Slash, Sweep, Thrust, Fire }
    public enum CombatEvent { None, Hit, Block, Deflect, Evade, Counter, Break, Finish }
    [Serializable]
    public sealed class Move
    {
        public MoveKind Kind;
        public float Windup, Active, Recovery, Reach, Damage, Posture;
        public Move(MoveKind kind, float windup, float reach, float damage, float posture)
        { Kind=kind; Windup=windup; Reach=reach; Damage=damage; Posture=posture; Active=.12f; Recovery=.42f; }
        public float Duration { get { return Windup+Active+Recovery; } }
    }
    public sealed class Fighter
    {
        public float X, Health=100, Posture, Clock, GuardAge=99, JumpLeft, StepLeft, StunLeft, BreakLeft, Quiet;
        public bool Guard;
        public Move Move;
        public bool ContactDone;
        public bool Alive { get { return Health>0; } }
        public bool Free { get { return Alive && Move==null && StunLeft<=0 && BreakLeft<=0; } }
        public float AttackProgress { get { return Move==null ? 0 : Clock/Move.Duration; } }
    }
    public sealed class Duel
    {
        public readonly Fighter Player=new Fighter { X=-2.5f };
        public readonly Fighter Enemy=new Fighter { X=2.5f };
        public readonly int Boss;
        public float Time, Cooldown=1.5f, FireCooldown;
        public CombatEvent LastEvent;
        public float EventTime;
        public bool EventOnEnemy;
        public bool Won { get { return !Enemy.Alive; } }
        public bool Lost { get { return !Player.Alive; } }
        private int pattern;
        public Duel(int boss) { Boss=Math.Max(0,Math.Min(3,boss)); }
        public void Guard(bool held)
        {
            if(held && !Player.Guard && Player.Free) Player.GuardAge=0;
            Player.Guard=held && Player.Free;
        }
        public void Attack()
        {
            if(!Player.Free) return;
            if(Enemy.BreakLeft>0 && Math.Abs(Player.X-Enemy.X)<2.4f) { Enemy.Health=0; Emit(CombatEvent.Finish,true); return; }
            Start(Player,new Move(MoveKind.Slash,.22f,2.1f,11,16));
        }
        public void Jump() { if(Player.Free && Player.JumpLeft<=0) Player.JumpLeft=.65f; }
        public void Step()
        {
            if(Player.Free && Player.StepLeft<=0) { Player.StepLeft=.24f; Player.Guard=false; }
        }
        public void Fire()
        {
            if(Player.Free && FireCooldown<=0) { Start(Player,new Move(MoveKind.Fire,.45f,4.5f,18,25)); FireCooldown=7; }
        }
        public void Tick(float dt,float movement)
        {
            if(dt<=0 || dt>.1f || Won || Lost) return;
            Time+=dt; FireCooldown=Math.Max(0,FireCooldown-dt);
            Advance(Player,dt); Advance(Enemy,dt);
            if(Player.Free && !Player.Guard) Player.X+=Math.Max(-1,Math.Min(1,movement))*3.3f*dt;
            if(Player.StepLeft>0) Player.X+=Math.Sign(Enemy.X-Player.X)*5.5f*dt;
            Player.X=Clamp(Player.X,-6.8f,6.8f);
            Enemy.X=Clamp(Enemy.X,-6.8f,6.8f);
            float distance=Math.Abs(Enemy.X-Player.X);
            // Bodies do not cross: preserve readable facing and stop at contact.
            if(distance<.75f) { float middle=(Enemy.X+Player.X)*.5f; Player.X=middle-.375f; Enemy.X=middle+.375f; }
            if(Enemy.Free)
            {
                Cooldown-=dt;
                if(distance>2.3f) Enemy.X+=Math.Sign(Player.X-Enemy.X)*(1.1f+Boss*.18f)*dt;
                if(Cooldown<=0 && distance<3.3f)
                {
                    var kind=(pattern%5==3)?MoveKind.Sweep:(pattern%5==4?MoveKind.Thrust:MoveKind.Slash);
                    float windup=Boss==0?.8f:Boss==1?.44f:Boss==2?.39f:.72f;
                    var move=new Move(kind,windup, Boss==3?3.6f:2.7f,kind==MoveKind.Slash?14:23,20);
                    if(kind!=MoveKind.Slash) move.Windup+=.3f;
                    move.Recovery=Boss==0?.7f:.36f;
                    Start(Enemy,move); pattern++;
                    Cooldown=pattern%3==0?1.25f:.13f;
                }
            }
            Contact(Player,Enemy,true);
            Contact(Enemy,Player,false);
        }
        private void Advance(Fighter f,float dt)
        {
            f.GuardAge+=dt; f.Quiet+=dt;
            f.JumpLeft=Math.Max(0,f.JumpLeft-dt); f.StepLeft=Math.Max(0,f.StepLeft-dt);
            f.StunLeft=Math.Max(0,f.StunLeft-dt);
            if(f.BreakLeft>0)
            {
                f.BreakLeft-=dt;
                if(f.BreakLeft<=0) f.Posture=55;
            }
            else if(f.Quiet>1.6f) f.Posture=Math.Max(0,f.Posture-dt*(f.Guard?20:9)*(f.Health/100f));
            if(f.Move!=null) { f.Clock+=dt; if(f.Clock>=f.Move.Duration) f.Move=null; }
        }
        private void Contact(Fighter attacker,Fighter target,bool onEnemy)
        {
            var m=attacker.Move;
            if(m==null || attacker.ContactDone || attacker.Clock<m.Windup) return;
            attacker.ContactDone=true;
            if(Math.Abs(attacker.X-target.X)>m.Reach || !target.Alive) return;
            attacker.Quiet=target.Quiet=0;
            if(!onEnemy)
            {
                if(m.Kind==MoveKind.Sweep && target.JumpLeft>0) { AddPosture(attacker,22,!onEnemy); Emit(CombatEvent.Counter,onEnemy); return; }
                if(m.Kind==MoveKind.Thrust && target.StepLeft>0) { AddPosture(attacker,35,!onEnemy); attacker.Move=null; attacker.StunLeft=.65f; Emit(CombatEvent.Counter,onEnemy); return; }
                if(m.Kind==MoveKind.Slash && target.StepLeft>0) { Emit(CombatEvent.Evade,onEnemy); return; }
            }
            // Enemy guard uses its own state; it cannot cancel an active attack to read player input.
            bool guard=onEnemy ? target.Free && target.JumpLeft<=0 : target.Guard;
            if(guard && (m.Kind==MoveKind.Slash || m.Kind==MoveKind.Fire))
            {
                bool perfect=!onEnemy && target.GuardAge<=.18f;
                if(perfect) { AddPosture(attacker,24,!onEnemy); Emit(CombatEvent.Deflect,onEnemy); }
                else { AddPosture(target,m.Posture,onEnemy); if(m.Kind==MoveKind.Fire) target.Health=Math.Max(0,target.Health-5); Emit(CombatEvent.Block,onEnemy); }
            }
            else
            {
                target.Health=Math.Max(0,target.Health-m.Damage);
                bool committed=onEnemy && target.Move!=null && target.Clock<target.Move.Windup+target.Move.Active;
                if(!committed) { target.Move=null; target.StunLeft=.28f; }
                target.Guard=false;
                AddPosture(target,m.Posture*.6f,onEnemy); Emit(CombatEvent.Hit,onEnemy);
            }
        }
        private void AddPosture(Fighter target,float amount,bool onEnemy)
        {
            target.Posture=Math.Min(100,target.Posture+amount);
            if(target.Posture>=100) { target.BreakLeft=2.5f; target.Move=null; target.Guard=false; Emit(CombatEvent.Break,onEnemy); }
        }
        private void Start(Fighter f,Move move) { f.Move=move; f.Clock=0; f.ContactDone=false; f.Guard=false; }
        private void Emit(CombatEvent e,bool onEnemy) { LastEvent=e; EventTime=Time; EventOnEnemy=onEnemy; }
        private static float Clamp(float x,float lo,float hi) { return Math.Max(lo,Math.Min(hi,x)); }
    }
}
