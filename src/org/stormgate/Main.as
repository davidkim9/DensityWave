package org.stormgate
{
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.text.TextField;
	import flash.utils.getTimer;
	import org.stormgate.particle.RenderParticle;
	
	/**
	 * ...
	 * @author David Kim
	 */
	public class Main extends Sprite 
	{
		private var txt:TextField;
		private var t:int = 0;
		
		private var render:RenderParticle;
		
		public function Main():void 
		{
			if (stage) init();
			else addEventListener(Event.ADDED_TO_STAGE, init);
		}
		
		private function init(e:Event = null):void 
		{
			removeEventListener(Event.ADDED_TO_STAGE, init);
			// entry point
			stage.scaleMode = StageScaleMode.NO_SCALE;
			stage.align = StageAlign.TOP_LEFT;
			
			//FPS COUNTER
			txt = new TextField();
			txt.textColor = 0xFFFFFF;
			addChild(txt);
			
			render = new RenderParticle(stage.stage3Ds[0]);
			addEventListener(Event.ENTER_FRAME, onFrame);
		}
		
		private function onFrame(e:Event = null):void {
			var time:int = getTimer();
			var fps:int = 1000 / (time - t);
			
			render.render();
			
			var execution:int = getTimer() - time;
			txt.text = "E: " + execution + "ms\nFPS:" + fps;
			t = time;
		}
		
	}
	
}