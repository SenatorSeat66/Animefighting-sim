using UnityEngine;
using System.Collections.Generic;
namespace ShadowFighting
{
    public sealed class ShadowGame : MonoBehaviour
    {
        static readonly string[] Names={"IRON ABBOT","ASH DANCER","VEILED TALON","SPEAR WARDEN"};
        static readonly string[] Lessons={"Move into range. Tap STRIKE to attack.","Hold GUARD to block. Tap it just before contact to DEFLECT.","Red SWEEP: JUMP. Red THRUST: STEP toward your opponent.","Fill enemy posture, then STRIKE nearby to finish."};
        Duel duel; int stage, page, lesson; float accumulator, effectUntil, shake, moveInput;
        float seenEvent=-1, hitstop; bool holdGuard, paused, muted, effects=true;
        SpriteRenderer hero, enemy, backdrop; Camera cam; AudioSource audioSource;
        Texture2D circle; Sprite[,] poses=new Sprite[5,12]; Sprite[] backgrounds=new Sprite[4];
        readonly List<Particle> particles=new List<Particle>();
        GUIStyle title,heading,body,small,button; Font font; Rect safe;
        readonly Color gold=new Color(.88f,.67f,.37f), paper=new Color(.91f,.88f,.77f);
        class Particle { public SpriteRenderer View; public Vector3 Velocity; public float Life; }
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        static void Boot() { if(FindFirstObjectByType<ShadowGame>()==null) new GameObject("Shadow Fighting").AddComponent<ShadowGame>(); }
        void Awake()
        {
            Application.targetFrameRate=60; Screen.sleepTimeout=SleepTimeout.NeverSleep;
            Screen.orientation=ScreenOrientation.LandscapeLeft;
            font=Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
            cam=Camera.main; if(!cam) cam=new GameObject("Duel Camera",typeof(Camera),typeof(AudioListener)).GetComponent<Camera>();
            cam.orthographic=true; cam.orthographicSize=5.625f; cam.transform.position=new Vector3(0,0,-10); cam.backgroundColor=new Color(.1f,.12f,.14f);
            audioSource=gameObject.AddComponent<AudioSource>(); muted=PlayerPrefs.GetInt("muted",0)==1;
            circle=new Texture2D(64,64,TextureFormat.RGBA32,false);
            for(int y=0;y<64;y++) for(int x=0;x<64;x++) circle.SetPixel(x,y,new Color(1,1,1,Mathf.Clamp01(32-Vector2.Distance(new Vector2(x,y),new Vector2(31.5f,31.5f)))));
            circle.Apply();
            for(int v=0;v<5;v++)
            {
                var t=Resources.Load<Texture2D>("Art/fighter-"+v);
                if(!t) { Debug.LogError("Missing authored fighter atlas "+v); continue; }
                for(int i=0;i<12;i++) poses[v,i]=Sprite.Create(t,new Rect((i%4)*512,(2-i/4)*512,512,512),new Vector2(.5f,.17f),128);
            }
            for(int i=0;i<4;i++) { var t=Resources.Load<Texture2D>("Art/arena-"+i); if(t) backgrounds[i]=Sprite.Create(t,new Rect(0,0,t.width,t.height),new Vector2(.5f,.5f),t.height/11.25f); }
            backdrop=Renderer("Painted arena",0); hero=Renderer("Ronin",3); enemy=Renderer("Opponent",2);
            backdrop.sprite=backgrounds[0]; hero.sprite=poses[0,0]; enemy.sprite=poses[1,0];
            hero.transform.position=new Vector3(-2.5f,-2.5f); enemy.transform.position=new Vector3(2.5f,-2.5f); enemy.flipX=true;
            stage=0; page=0;
        }
        SpriteRenderer Renderer(string name,int order) { var r=new GameObject(name).AddComponent<SpriteRenderer>(); r.sortingOrder=order; return r; }
        void Begin(int level) { stage=level; duel=new Duel(stage); page=1; paused=false; holdGuard=false; seenEvent=-1; hitstop=0; accumulator=0; backdrop.sprite=backgrounds[stage]; }
        Vector2 Virtual(Vector2 p) { return new Vector2((p.x-safe.x)/safe.width*1920,(safe.yMax-p.y)/safe.height*1080); }
        Rect[] controls={new Rect(70,800,170,170),new Rect(255,800,170,170),new Rect(1650,785,190,190),new Rect(1435,820,170,170),new Rect(1540,600,150,150),new Rect(1740,595,150,150),new Rect(1325,620,150,150)};
        void Update()
        {
            safe=Screen.safeArea; if(safe.width<=0) safe=new Rect(0,0,Screen.width,Screen.height);
            cam.orthographicSize=Mathf.Max(5.625f,10f/cam.aspect);
            if(page!=1 || paused) return;
            moveInput=0; bool guard=false;
            for(int i=0;i<Input.touchCount;i++)
            {
                var t=Input.GetTouch(i); if(t.phase==TouchPhase.Ended || t.phase==TouchPhase.Canceled) continue;
                HandlePoint(Virtual(t.position),t.phase==TouchPhase.Began,ref guard);
            }
#if UNITY_EDITOR || UNITY_STANDALONE
            moveInput=(Input.GetKey(KeyCode.D)?1:0)-(Input.GetKey(KeyCode.A)?1:0); guard=Input.GetKey(KeyCode.K);
            if(Input.GetKeyDown(KeyCode.J)) duel.Attack(); if(Input.GetKeyDown(KeyCode.Space)) duel.Jump();
            if(Input.GetKeyDown(KeyCode.L)) duel.Step(); if(Input.GetKeyDown(KeyCode.I)) duel.Fire();
            if(Input.GetMouseButton(0)) HandlePoint(Virtual(Input.mousePosition),Input.GetMouseButtonDown(0),ref guard);
#endif
            holdGuard=guard; duel.Guard(guard);
            if(Input.GetKeyDown(KeyCode.Escape)) { paused=true; duel.Guard(false); }
            if(hitstop>0) hitstop-=Time.unscaledDeltaTime;
            else { accumulator+=Mathf.Min(Time.deltaTime,.1f); while(accumulator>=1f/120f) { duel.Tick(1f/120f,moveInput); accumulator-=1f/120f; } }
            if(duel.EventTime!=seenEvent && duel.LastEvent!=CombatEvent.None)
            {
                seenEvent=duel.EventTime; effectUntil=Time.unscaledTime+.65f;
                bool perfect=duel.LastEvent==CombatEvent.Deflect || duel.LastEvent==CombatEvent.Counter;
                shake=effects?(perfect?.08f:.04f):0; hitstop=effects?(perfect?.055f:.025f):0;
                Impact(new Vector3(duel.EventOnEnemy?duel.Enemy.X:duel.Player.X,-.8f,0),perfect?gold:paper);
                if(!muted) { var sound=Resources.Load<AudioClip>("Audio/"+(perfect?"deflect":"impact")); if(sound) audioSource.PlayOneShot(sound,.5f); }
            }
            Display(hero,duel.Player,0,false); Display(enemy,duel.Enemy,stage+1,true);
            cam.transform.position=new Vector3(effects?Mathf.Sin(Time.unscaledTime*127)*shake:0,0,-10); shake=Mathf.MoveTowards(shake,0,Time.deltaTime*.4f);
            for(int i=particles.Count-1;i>=0;i--)
            {
                var p=particles[i]; p.Life-=Time.deltaTime;
                if(p.Life<=0) { Destroy(p.View.gameObject); particles.RemoveAt(i); continue; }
                p.View.transform.position+=p.Velocity*Time.deltaTime; p.Velocity+=Vector3.down*Time.deltaTime*4;
                var c=p.View.color;c.a=p.Life/.4f;p.View.color=c;
            }
            if(duel.Won) PlayerPrefs.SetInt("unlocked",Mathf.Max(PlayerPrefs.GetInt("unlocked",0),Mathf.Min(3,stage+1)));
        }
        void HandlePoint(Vector2 p,bool down,ref bool guard)
        {
            if(controls[0].Contains(p)) moveInput=-1; if(controls[1].Contains(p)) moveInput=1;
            if(controls[3].Contains(p)) guard=true;
            if(!down) return;
            if(controls[2].Contains(p)) duel.Attack(); if(controls[4].Contains(p)) duel.Jump();
            if(controls[5].Contains(p)) duel.Step(); if(controls[6].Contains(p)) duel.Fire();
        }
        void Display(SpriteRenderer r,Fighter f,int v,bool flip)
        {
            int pose=0;
            if(!f.Alive) pose=10;
            else if(f.BreakLeft>0 || f.StunLeft>0) pose=8;
            else if(f.JumpLeft>0) pose=6;
            else if(f.StepLeft>0) pose=7;
            else if(f.Guard) pose=5;
            else if(f.Move!=null) pose=f.Move.Kind==MoveKind.Fire?11:(f.Clock<f.Move.Windup?3:4);
            else if((v==0 && Mathf.Abs(moveInput)>.1f) || (v>0 && Mathf.Abs(duel.Player.X-duel.Enemy.X)>2.3f)) pose=1+(int)(duel.Time*7)%2;
            r.sprite=poses[v,pose];r.flipX=flip;
            float jump=f.JumpLeft>0?Mathf.Sin((1-f.JumpLeft/.65f)*Mathf.PI)*1.3f:0;
            r.transform.position=new Vector3(f.X,-2.5f+jump+Mathf.Sin(duel.Time*2)*.012f,0);
        }
        void Impact(Vector3 at,Color color)
        {
            if(!effects) return;
            var sprite=Sprite.Create(circle,new Rect(0,0,64,64),new Vector2(.5f,.5f),128);
            for(int i=0;i<12;i++) { var r=Renderer("Contact spark",10); r.sprite=sprite; r.color=color; r.transform.position=at; r.transform.localScale=new Vector3(.15f,.025f,1); float a=i*Mathf.PI/6; r.transform.rotation=Quaternion.Euler(0,0,a*Mathf.Rad2Deg);particles.Add(new Particle{View=r,Velocity=new Vector3(Mathf.Cos(a),Mathf.Sin(a))*Random.Range(2f,5f),Life=.4f}); }
            Destroy(sprite,1);
        }
        GUIStyle Style(int size,Color color,TextAnchor align=TextAnchor.MiddleLeft) { return new GUIStyle{font=font,fontSize=size,alignment=align,normal={textColor=color},wordWrap=true}; }
        void Styles() { if(title!=null)return;title=Style(100,paper);heading=Style(36,gold);body=Style(29,paper);small=Style(22,paper);button=Style(26,paper,TextAnchor.MiddleCenter); }
        void Box(Rect r,Color c) { GUI.color=c;GUI.DrawTexture(r,Texture2D.whiteTexture);GUI.color=Color.white; }
        bool Button(Rect r,string text) { Box(r,new Color(.06f,.08f,.1f,.94f)); Box(new Rect(r.x,r.y,r.width,2),gold);return GUI.Button(r,text,button); }
        void Bar(float x,float y,float value,Color c) { Box(new Rect(x,y,640,13),new Color(.1f,.12f,.14f,.9f));Box(new Rect(x,y,640*Mathf.Clamp01(value/100),13),c); }
        void OnGUI()
        {
            Styles(); var old=GUI.matrix; GUI.matrix=Matrix4x4.TRS(new Vector3(safe.x,Screen.height-safe.yMax,0),Quaternion.identity,new Vector3(safe.width/1920,safe.height/1080,1));
            if(page==0)
            {
                Box(new Rect(0,0,1920,1080),new Color(0,0,0,.35f));
                GUI.Label(new Rect(130,120,1000,60),"A DUEL OF STEEL & SHADOW",heading);
                GUI.Label(new Rect(120,200,1200,140),"SHADOW FIGHTING",title);
                GUI.Label(new Rect(130,350,750,100),"Stand your ground. Read the blade.\nTurn perfect defense into a decisive strike.",body);
                if(Button(new Rect(130,500,460,90),"ENTER THE TRIALS"))Begin(0);
                if(Button(new Rect(130,620,460,75),"LEARN THE BLADE")){page=2;lesson=0;}
                if(Button(new Rect(130,725,220,65),muted?"SOUND OFF":"SOUND ON")){muted=!muted;PlayerPrefs.SetInt("muted",muted?1:0);}
                if(Button(new Rect(370,725,220,65),effects?"FX ON":"FX OFF"))effects=!effects;
                int unlocked=PlayerPrefs.GetInt("unlocked",0);
                for(int i=0;i<4;i++){GUI.enabled=i<=unlocked;if(Button(new Rect(1280,480+i*90,480,70),(i+1)+" / "+Names[i]))Begin(i);GUI.enabled=true;}
            }
            else if(page==2)
            {
                Box(new Rect(0,0,1920,1080),new Color(0,0,0,.75f));GUI.Label(new Rect(180,180,1300,100),"THE WAY OF THE BLADE",heading);
                GUI.Label(new Rect(180,340,1350,180),Lessons[lesson],Style(45,paper));
                GUI.Label(new Rect(180,560,1400,80),"Desktop: A/D move · J strike · K guard · SPACE jump · L step · I fire",body);
                if(Button(new Rect(180,740,380,80),lesson<3?"NEXT LESSON":"START TRAINING")){if(lesson<3)lesson++;else Begin(0);}
                if(Button(new Rect(600,740,300,80),"BACK"))page=0;
            }
            else if(duel!=null)
            {
                GUI.Label(new Rect(70,40,600,60),"RONIN",heading);GUI.Label(new Rect(1210,40,640,60),Names[stage],heading);
                Bar(70,110,duel.Player.Health,paper);Bar(1210,110,duel.Enemy.Health,paper);
                Bar(70,135,duel.Player.Posture,gold);Bar(1210,135,duel.Enemy.Posture,gold);
                GUI.Label(new Rect(760,65,400,60),"TRIAL "+(stage+1)+" / 4",Style(27,gold,TextAnchor.MiddleCenter));
                if(Button(new Rect(895,160,130,55),"PAUSE")){paused=true;duel.Guard(false);}
                string[] labels={"◀","▶","STRIKE","GUARD","JUMP","STEP",duel.FireCooldown>0?"FIRE "+Mathf.CeilToInt(duel.FireCooldown):"FIRE"};
                for(int i=0;i<controls.Length;i++){GUI.color=new Color(.04f,.06f,.08f,.7f);GUI.DrawTexture(controls[i],circle);GUI.color=Color.white;GUI.Label(controls[i],labels[i],button);}
                var m=duel.Enemy.Move;
                if(m!=null && m.Kind!=MoveKind.Slash && duel.Enemy.Clock<m.Windup)
                { GUI.Label(new Rect(650,270,620,90),m.Kind==MoveKind.Sweep?"SWEEP — JUMP":"THRUST — STEP",Style(42,new Color(1,.25f,.16f),TextAnchor.MiddleCenter)); }
                if(duel.Enemy.BreakLeft>0) GUI.Label(new Rect(600,380,720,80),"POSTURE BROKEN · STRIKE TO FINISH",Style(34,gold,TextAnchor.MiddleCenter));
                else if(Time.unscaledTime<effectUntil)GUI.Label(new Rect(700,340,520,70),duel.LastEvent.ToString().ToUpperInvariant(),Style(34,gold,TextAnchor.MiddleCenter));
                if(paused || duel.Won || duel.Lost)
                {
                    Box(new Rect(0,0,1920,1080),new Color(0,0,0,.78f));
                    string text=paused?"STILLNESS":duel.Won?"TRIAL COMPLETE":"RISE AGAIN";
                    GUI.Label(new Rect(500,260,1100,150),text,Style(76,paper,TextAnchor.MiddleCenter));
                    if(Button(new Rect(700,490,520,90),paused?"RESUME":duel.Won && stage<3?"NEXT TRIAL":"RETRY"))
                    {if(paused)paused=false;else Begin(duel.Won && stage<3?stage+1:stage);}
                    if(Button(new Rect(700,620,520,80),"RETURN TO SANCTUARY")){page=0;paused=false;}
                }
            }
            GUI.matrix=old;
        }
        void OnApplicationPause(bool isPaused) { if(isPaused && page==1) {paused=true;holdGuard=false;duel.Guard(false);} }
    }
}
