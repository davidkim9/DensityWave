package org.stormgate.particle 
{
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.display.Stage3D;
	import flash.display3D.IndexBuffer3D;
	import flash.display3D.VertexBuffer3D;
	import flash.display3D.Context3D;
	import flash.display3D.Context3DProgramType;
	import flash.display3D.Context3DVertexBufferFormat;
	import flash.display3D.Program3D;
	import flash.display3D.textures.Texture;
	import flash.display3D.Context3DTriangleFace;
	import flash.display3D.Context3DTextureFormat;
	
	import flash.display3D.Context3DBlendFactor;
	import flash.display3D.Context3DCompareMode;
	
	import flash.geom.Matrix3D;
	import flash.geom.Vector3D;
	import flash.utils.getTimer;
	
	import com.adobe.utils.AGALMiniAssembler;
	
	import flash.utils.getTimer
	/**
	 * ...
	 * @author David Kim
	 */
	public class RenderParticle 
	{
		private var width:int = 1280;
		private var height:int = 800;
		private var antialias:int = 2;
		
		private var stage3D:Stage3D;
		private var context:Context3D;
		
		private var programStars:Program3D;
		
		private var projectionMatrix:Matrix3D;
		
		//View
		private var position:Vector3D
		private var radius:Number;
		private var rotMatrix:Matrix3D;
		
		private var starBuffers:Vector.<StarBuffers>;
		
		//Alpha Texture
		[Embed(source="alpha.png")]
		private var TextureAlpha:Class;
		
		public function RenderParticle(stage:Stage3D) 
		{
			this.stage3D = stage;
			
			stage3D.addEventListener(Event.CONTEXT3D_CREATE, initStage3D);
			stage3D.requestContext3D();
			
			//Build Projection Matrix
			projectionMatrix = new Matrix3D();
			
			var fieldOfViewY:Number = 45 * Math.PI / 180;
			var aspectRatio:Number = width / height;
			var zNear:Number = 0.1;
			var zFar:Number = 1000;
			var yScale:Number = 1.0/Math.tan(fieldOfViewY/2.0);
			var xScale:Number = yScale / aspectRatio;
			
			projectionMatrix.copyRawDataFrom(Vector.<Number>([
				xScale, 0.0, 0.0, 0.0,
				0.0, yScale, 0.0, 0.0,
				0.0, 0.0, zFar/(zFar-zNear), 1.0,
				0.0, 0.0, (zNear*zFar)/(zNear-zFar), 0.0
			]));
			
			radius = 80;
			position = new Vector3D(0, 0, 0);
			rotMatrix = new Matrix3D();
			
			starBuffers = new Vector.<StarBuffers>();
		}
		
		protected function initStage3D(e:Event):void
		{
			context = stage3D.context3D;
			context.configureBackBuffer(width, height, antialias, true);
			
			context.enableErrorChecking = true;
			
			context.setCulling(Context3DTriangleFace.BACK);
			context.setDepthTest(true, Context3DCompareMode.ALWAYS); 
			context.setBlendFactors(Context3DBlendFactor.ONE, Context3DBlendFactor.ONE_MINUS_SOURCE_COLOR);
			
			createProgramStars();
			
			var data:Vector.<Number> = Vector.<Number>([-1, -1, 0, 1]);
			context.setProgramConstantsFromVector(Context3DProgramType.VERTEX, 10, data, 1);
			data = Vector.<Number>([0, 1, 0, 1]);
			context.setProgramConstantsFromVector(Context3DProgramType.VERTEX, 11, data, 1);
			data = Vector.<Number>([1, -1, 0, 1]);
			context.setProgramConstantsFromVector(Context3DProgramType.VERTEX, 12, data, 1);
			
			initParticlesStars();
			createTexture();
		}
		
		private function createProgramStars():void
		{
			programStars = context.createProgram();
			
			//Shader Language
			var vertexCode:String = "";
			var fragmentCode:String = "";
			
			vertexCode += "mov vt1, va0\n";
			
			//Start theta, radius, rotation, size
			//va2.x, va2.y, va2.z
			//vc9 = 1.2
			
			vertexCode += "mul vt2, vt1.y, vc20.y \n"; // theta * distributionScale
			vertexCode += "add vt3, va2.x, vt2 \n"; // vt3 = startTheta + dt
			
			//Z Stuff
			vertexCode += "sin vt4, vt3\n";
			vertexCode += "mul vt1.z, vt4, vt1.z\n";
			//vertexCode += "mov vt1.z, vt4\n";
			
			//x = radius * 1.2 * Math.sin(theta);
			vertexCode += "mul vt4, va2.y, vc20.x \n"; // radius * 1.2
			vertexCode += "sin vt5, vt3 \n"; // vt5 = sin(vt3)
			vertexCode += "mul vt4, vt4, vt5 \n"; // vt4(x) = radius * 1.2 * sin(vt3)
			
			//y = radius * Math.cos(theta);
			vertexCode += "cos vt5, vt3\n"; // vt5 = cos(vt3)
			vertexCode += "mul vt5, va2.y, vt5 \n"; // vt5(y) = radius * cos(vt3)
			
			//Rotation Matrix
			vertexCode += "sin vt6, va2.z\n";
			vertexCode += "cos vt7, va2.z\n";
			
			//x * Math.cos(rot) - y * Math.sin(rot)
			vertexCode += "mul vt2, vt4, vt7\n";
			vertexCode += "mul vt3, vt5, vt6\n";
			vertexCode += "sub vt2, vt2, vt3\n";
			
			//x * Math.sin(rot) + y * Math.cos(rot)
			vertexCode += "mul vt4, vt4, vt6\n";
			vertexCode += "mul vt5, vt5, vt7\n";
			vertexCode += "add vt6, vt4, vt5\n";
			
			// set new position for vertice 
			vertexCode += "mov vt1.x, vt2\n"; 
			vertexCode += "mov vt1.y, vt6\n";
			
			//Face Camera
			vertexCode += "mov vt2, vc[va0.w]\n";
			vertexCode += "m33 vt0.xyz, vt2.xyz, vc13\n";
			vertexCode += "mov vt0.w, vt2.w\n";
			vertexCode += "mul vt0.xyz, vt0.xyz, va2.w \n";
			vertexCode += "add vt0.xyz, vt0.xyz, vt1.xyz \n"; // set new position for vertice 
			vertexCode += "m44 op, vt0, vc0 \n";              // transform and output vertex x,y,z
			vertexCode += "mov v0, va1 \n";
			vertexCode += "mov v1, va0.y \n";
			vertexCode += "mov v2, vc20 \n";
			
			//Fragment Shader
			
			fragmentCode += "tex ft0, v0, fs0 <2d,linear> \n";
			fragmentCode += "mul ft0.w, ft0.w, ft0.w\n";
			fragmentCode += "sub ft2.x, ft0.w, fc0.y \n";
			fragmentCode += "kil ft2.x\n";
			fragmentCode += "mov ft0.xyz, v2.w\n";
			fragmentCode += "mov ft0.xyzw, v1.z\n";
			fragmentCode += "mov oc, ft0\n";
			
			var vertexCompiler:AGALMiniAssembler = new AGALMiniAssembler();
			vertexCompiler.assemble(Context3DProgramType.VERTEX, vertexCode, false);
			
			var fragmentCompiler:AGALMiniAssembler = new AGALMiniAssembler();
			fragmentCompiler.assemble(Context3DProgramType.FRAGMENT, fragmentCode, false);
			
			programStars.upload(vertexCompiler.agalcode, fragmentCompiler.agalcode);
			//context.setProgram(programStars);
		}
		
		private function initParticlesStars():void 
		{
			// x, y, z, w
			var vertices:Vector.<Number> = new Vector.<Number>();
			var indices:Vector.<uint> = new Vector.<uint>();
			var uvData:Vector.<Number> = new Vector.<Number>();
			var particleData:Vector.<Number> = new Vector.<Number>();
			
			for (var n:int = 0; n < 45; n++) {
				var buffers:StarBuffers  = new StarBuffers();
				var partNum:int = 21845;
				
				for (var i:int = 0 ; i < partNum; i++) {
					
					var theta:Number = (2 - (4 * Math.random())) * Math.PI;
					var distRandom:Number = Math.random() * Math.random();
					var distribution:Number = distRandom * 140;
					var radius:Number = distribution * 0.2;
					var rot:Number = distribution * 0.045;// 52;
					
					//Height
					var alt:Number = (0.5 - distRandom) * (-5 + Math.random() * 10);
					
					var size:Number = 0.1*Math.random();
					
					var speed:Number = Math.pow((150 - distribution) / 150, 3) + Math.random() * 0.1;
					
					for (var j:int = 0 ; j < 3; j++){
						vertices[i * 12 + j * 4] = distribution;
						vertices[i * 12 + j * 4 + 1] = speed;
						vertices[i * 12 + j * 4 + 2] = alt;
						vertices[i * 12 + j * 4 + 3] = 10 + j;
						
						//Start theta, rotation, radius, size
						particleData[i * 12 + j * 4] = theta;
						particleData[i * 12 + j * 4 + 1] = radius;
						particleData[i * 12 + j * 4 + 2] = rot;
						particleData[i * 12 + j * 4 + 3] = size;
					}
					indices[i * 3] = i * 3;
					indices[i * 3 + 1] = i * 3 + 1;
					indices[i * 3 + 2] = i * 3 + 2;
					
					//uvData[i * 2] = 1;
					//uvData[i * 2] = 1; 0,1, .5,0, 1,1
					uvData[i * 6] = 0;
					uvData[i * 6 + 1] = 1;
					uvData[i * 6 + 2] = 0.5;
					uvData[i * 6 + 3] = 0;
					uvData[i * 6 + 4] = 1;
					uvData[i * 6 + 5] = 1;
				}
				
				buffers.vBufferStar = context.createVertexBuffer(vertices.length / 4, 4);
				buffers.vBufferStar.uploadFromVector(vertices, 0, vertices.length / 4);
				buffers.iBufferStar = context.createIndexBuffer(indices.length);
				buffers.iBufferStar.uploadFromVector(indices, 0, indices.length);
				buffers.uvBufferStar = context.createVertexBuffer(uvData.length / 2, 2);
				buffers.uvBufferStar.uploadFromVector(uvData, 0, uvData.length / 2);
				buffers.dataBufferStar = context.createVertexBuffer(particleData.length / 4, 4);
				buffers.dataBufferStar.uploadFromVector(particleData, 0, particleData.length / 4);
				
				starBuffers[n] = buffers;
			}
			
			
		}
		
		private function createTexture():void {
			var texture:Texture;
			
			var bg:Bitmap = new TextureAlpha();
			texture = context.createTexture(bg.width, bg.height, Context3DTextureFormat.BGRA, false);
			texture.uploadFromBitmapData(bg.bitmapData);
			context.setTextureAt(0, texture);
		}
		
		public function render():void
		{
			if ( !context ) 
				return;
			
			//context.clear(0,0.2);
			context.clear();
			
			//Prepare Matrix
			rotMatrix.appendRotation(0.1, Vector3D.X_AXIS);
			rotMatrix.appendRotation(0.2, Vector3D.Y_AXIS);
			
			var invertCam:Matrix3D = new Matrix3D();
			rotMatrix.copyToMatrix3D(invertCam);
			invertCam.invert();
			
			var m:Matrix3D = new Matrix3D();
			m.append(rotMatrix);
			m.appendTranslation(0, 0, radius);
			m.append(projectionMatrix);
			//m.appendRotation(getTimer() / 40, Vector3D.Y_AXIS);
			
			context.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX, 0, m, true);
			context.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX, 13, invertCam, true);
			context.setProgramConstantsFromVector(Context3DProgramType.VERTEX, 20, Vector.<Number>([1.5, getTimer() / 1500.0, 0.0, 0xFFFF00FF]));
			context.setProgramConstantsFromVector(Context3DProgramType.VERTEX, 21, Vector.<Number>([-0.1, 0.1, 0.2, 0.3]));
			
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, Vector.<Number>([0.5, 0.2, 0, 0]));
			
			context.setProgram(programStars);
			context.setVertexBufferAt(3, null);
			
			
			for (var n:int = 0 ; n < starBuffers.length; n++) {
				context.setVertexBufferAt(0, starBuffers[n].vBufferStar, 0, Context3DVertexBufferFormat.FLOAT_4);
				context.setVertexBufferAt(1, starBuffers[n].uvBufferStar, 0, Context3DVertexBufferFormat.FLOAT_2);
				context.setVertexBufferAt(2, starBuffers[n].dataBufferStar, 0, Context3DVertexBufferFormat.FLOAT_4);
				context.drawTriangles(starBuffers[n].iBufferStar);
			}
			
			context.present();
		}
	}

}