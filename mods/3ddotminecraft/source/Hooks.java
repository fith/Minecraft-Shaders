// Bytecode patcher for GLSL shaders.  
// I don't care what you do with this source but I'd like some credit if you reuse this in part or whole. - daxnitro

import javassist.*;
import javassist.expr.*;

import java.io.File;
import java.io.DataOutputStream;
import java.io.FileOutputStream;

import java.lang.Exception;

import daxnitro.nitrous.ModHooks;
import daxnitro.nitrous.PreferenceManager;

public class Hooks implements ModHooks {
	public boolean install(File installDir) throws Throwable {

		String dirPath = installDir.getPath();

		ClassPool pool = ClassPool.getDefault();
		pool.appendClassPath(dirPath);
		pool.appendClassPath(new File(new File(Hooks.class.getProtectionDomain().getCodeSource().getLocation().toURI()).getParentFile(), "files").getPath());
		
		String lwjglPath = new File(new File(PreferenceManager.getStringValue(PreferenceManager.MC_JAR_PATH_KEY)).getParentFile(), "lwjgl.jar").getPath();
		pool.appendClassPath(lwjglPath);

		// EntityRenderer.class

		CtClass entityRenderer = pool.get(EntityRenderer);
 
 		CtClass floatParameter[] = {CtClass.floatType};
 		
		CtMethod renderEverything = entityRenderer.getDeclaredMethod(EntityRenderer_renderEverything, floatParameter);

		final Hooks hooks = this;

		renderEverything.instrument(
			new ExprEditor() {
				public void edit(MethodCall m) throws CannotCompileException {
					if (m.getClassName().equals("Shaders") && m.getMethodName().equals("processScene")) {
						hooks.alreadyInstalled = true;
					}
				}
			}
		);
		
		if (alreadyInstalled) {
			System.out.println("Already installed.");
			return true;
		}
		
		renderEverything.instrument(
			new ExprEditor() {
				public void edit(MethodCall m) throws CannotCompileException {
					if (m.getClassName().equals(EntityRenderer) && m.getMethodName().equals(EntityRenderer_renderWorld) && m.getSignature().equals("(F)V")) {
						m.replace("{ $_ = $proceed($$); Shaders.processScene("+EntityRenderer_red+", "+EntityRenderer_green+", "+EntityRenderer_blue+"); }");
					} else if (m.getClassName().equals("org.lwjgl.opengl.GL11") && m.getMethodName().equals("glViewport")) {
						m.replace("{ Shaders.viewport($$); }");
					}
				}
			}
		);
		
		CtMethod renderWorld = entityRenderer.getDeclaredMethod(EntityRenderer_renderWorld, floatParameter);

		renderWorld.instrument(
			new ExprEditor() {
				public void edit(NewExpr e) throws CannotCompileException {
					if (e.getClassName().equals(Frustrum)) {
						e.replace("{ Shaders.useProgram(Shaders.baseProgram); $_ = $proceed($$); }");
					}
				}
			}
		);

		renderWorld.instrument(
			new ExprEditor() {
				public void edit(MethodCall m) throws CannotCompileException {
					if (m.getClassName().equals(EntityRenderer) && m.getMethodName().equals(EntityRenderer_renderPlayer) && m.getSignature().equals("(FI)V")) {
						m.replace("{ $_ = $proceed($$); Shaders.copyDepthTexture(Shaders.depthTexture2Id); Shaders.useProgram(0); }");
					} else if (m.getClassName().equals("org.lwjgl.opengl.GL11") && m.getMethodName().equals("glViewport")) {
						m.replace("{ Shaders.viewport($$); }");
					}
				}
			}
		);

		renderWorld.instrument(
			new ExprEditor() {
				public void edit(MethodCall m) throws CannotCompileException {
					if (m.getClassName().equals(RenderGlobal) && m.getMethodName().equals(RenderGlobal_renderClouds) && m.getSignature().equals("(F)V")) {
						m.replace("{ $_ = $proceed($$); Shaders.copyDepthTexture(Shaders.depthTextureId); }");
					}
				}
			}
		);

		renderWorld.instrument(
			new ExprEditor() {
				public void edit(MethodCall m) throws CannotCompileException {
					if (m.getClassName().equals(RenderGlobal) && m.getMethodName().equals(RenderGlobal_renderTerrain) && m.getSignature().equals(RenderGlobal_renderTerrain_sig)) {
						m.replace("{ if ($2 == 0) { Shaders.bindTexture(33985, "+EntityRenderer_mc+"."+Minecraft_renderEngine+"."+RenderEngine_getTexture+"(\"/terrain_nh.png\")); Shaders.bindTexture(33986, "+EntityRenderer_mc+"."+Minecraft_renderEngine+"."+RenderEngine_getTexture+"(\"/terrain_s.png\")); Shaders.setRenderType(1); Shaders.useProgram(Shaders.baseProgramBM); $_ = $proceed($$); Shaders.setRenderType(0); Shaders.useProgram(Shaders.baseProgram); } else { $_ = $proceed($$); } }");
					}
				}
			}
		);

		// Tessellator.class
		
		CtClass tessellator = pool.get(Tessellator);
 
 		tessellator.addField(new CtField(pool.get("java.nio.ByteBuffer"), "shadersBuffer", tessellator), "null");
 		tessellator.addField(new CtField(pool.get("java.nio.ShortBuffer"), "shadersShortBuffer", tessellator), "null");
 		tessellator.addField(new CtField(pool.get("short[]"), "shadersData", tessellator), "new short[]{-1, 0}");

 		CtClass int3Parameter[] = {CtClass.intType, CtClass.intType, CtClass.intType};
 
 		CtMethod setEntity = CtMethod.make("public void setEntity(int id, int brightness, int lightValue) {" +
			"shadersData[0] = (short)id;" +
			"shadersData[1] = (short)(brightness + lightValue * 16);" +
			"}", tessellator);
 		tessellator.addMethod(setEntity);
 
 		CtClass intParameter[] = {CtClass.intType};
 
 		tessellator.getDeclaredConstructor(intParameter).insertAfter(
			"shadersBuffer = " + GLAllocation + "." + GLAllocation_createDirectByteBuffer + "($1 / 8 * 4);" +
			"shadersShortBuffer = shadersBuffer.asShortBuffer();"
 		);
 		
 		CtClass noParameter[] = {};
 		
		CtMethod draw = tessellator.getDeclaredMethod(Tessellator_draw, noParameter);
		
		draw.instrument(
			new ExprEditor() {
				public void edit(MethodCall m) throws CannotCompileException {
					if (m.getClassName().equals("org.lwjgl.opengl.GL11") && m.getMethodName().equals("glDrawArrays")) {
						m.replace("{" + 
							"if (Shaders.entityAttrib >= 0) {" +
							"org.lwjgl.opengl.ARBVertexProgram.glEnableVertexAttribArrayARB(Shaders.entityAttrib);" +
							"org.lwjgl.opengl.ARBVertexProgram.glVertexAttribPointerARB(Shaders.entityAttrib, 2, false, false, 4, (java.nio.ShortBuffer)shadersShortBuffer.position(0));" +
							"}" +
							"$_ = $proceed($$);" +
							"if (Shaders.entityAttrib >= 0) { org.lwjgl.opengl.ARBVertexProgram.glDisableVertexAttribArrayARB(Shaders.entityAttrib); }" +
							"}");
					}
				}
			}
		);
		
		CtMethod reset = tessellator.getDeclaredMethod(Tessellator_reset, noParameter);
		
		reset.insertBefore("shadersBuffer.clear();");
		 
 		CtClass float3Parameter[] = {CtClass.floatType, CtClass.floatType, CtClass.floatType};
 		
		CtMethod setNormal = tessellator.getDeclaredMethod(Tessellator_setNormal, float3Parameter);

		setNormal.insertAfter(
			"byte byte0 = (byte)(int)($1 * 127F);" +
			""+Tessellator_normal+" &= 0xFFFFFF00;" +
			""+Tessellator_normal+" |= byte0;"
			);

 		CtClass double3Parameter[] = {CtClass.doubleType, CtClass.doubleType, CtClass.doubleType};
 		
		CtMethod addVertex = tessellator.getDeclaredMethod(Tessellator_addVertex, double3Parameter);

		addVertex.insertBefore(
			"if ("+Tessellator_drawMode+" == 7 && "+Tessellator_convertQuadsToTriangles+" && ("+Tessellator_addedVertices+" + 1) % 4 == 0 && "+Tessellator_hasNormals+") {" +
			""+Tessellator_rawBuffer+"["+Tessellator_rawBufferIndex+" + 6] = "+Tessellator_rawBuffer+"[("+Tessellator_rawBufferIndex+" - 24) + 6];" +
			"shadersBuffer.putShort(shadersData[0]).putShort(shadersData[1]);" +
			""+Tessellator_rawBuffer+"["+Tessellator_rawBufferIndex+" + 8 + 6] = "+Tessellator_rawBuffer+"[("+Tessellator_rawBufferIndex+" + 8 - 16) + 6];" +
			"shadersBuffer.putShort(shadersData[0]).putShort(shadersData[1]);" +
			"}" +
			"shadersBuffer.putShort(shadersData[0]).putShort(shadersData[1]);"
			);
		
		// RenderBlocks.class
		
		CtClass renderBlocks = pool.get(RenderBlocks);

		CtClass block = pool.get(Block);
		
 		CtClass renderFaceParameter[] = {block, CtClass.doubleType, CtClass.doubleType, CtClass.doubleType, CtClass.intType};
 		
		CtMethod renderBottomFace;
		try {
			renderBottomFace = renderBlocks.getDeclaredMethod(RenderBlocks_renderBottomFace, renderFaceParameter);
		} catch (NotFoundException e) {
			// Because Wild Grass doesn't reobfuscate this.
			renderBottomFace = renderBlocks.getDeclaredMethod("renderBottomFace", renderFaceParameter);
		}
		renderBottomFace.insertBefore(Tessellator+"."+Tessellator_instance+"."+Tessellator_setNormal+"(0.0F, -1.0F, 0.0F);");

		CtMethod renderTopFace;
		try {
			renderTopFace = renderBlocks.getDeclaredMethod(RenderBlocks_renderTopFace, renderFaceParameter);		
		} catch (NotFoundException e) {
			// Because Wild Grass doesn't reobfuscate this.
			renderTopFace = renderBlocks.getDeclaredMethod("renderTopFace", renderFaceParameter);		
		}
		renderTopFace.insertBefore(Tessellator+"."+Tessellator_instance+"."+Tessellator_setNormal+"(0.0F, 1.0F, 0.0F);");

		CtMethod renderEastFace = renderBlocks.getDeclaredMethod(RenderBlocks_renderEastFace, renderFaceParameter);		
		renderEastFace.insertBefore(Tessellator+"."+Tessellator_instance+"."+Tessellator_setNormal+"(0.0F, 0.0F, -1.0F);");

		CtMethod renderWestFace = renderBlocks.getDeclaredMethod(RenderBlocks_renderWestFace, renderFaceParameter);		
		renderWestFace.insertBefore(Tessellator+"."+Tessellator_instance+"."+Tessellator_setNormal+"(0.0F, 0.0F, 1.0F);");

		CtMethod renderNorthFace = renderBlocks.getDeclaredMethod(RenderBlocks_renderNorthFace, renderFaceParameter);		
		renderNorthFace.insertBefore(Tessellator+"."+Tessellator_instance+"."+Tessellator_setNormal+"(-1.0F, 0.0F, 0.0F);");

		CtMethod renderSouthFace = renderBlocks.getDeclaredMethod(RenderBlocks_renderSouthFace, renderFaceParameter);		
		renderSouthFace.insertBefore(Tessellator+"."+Tessellator_instance+"."+Tessellator_setNormal+"(1.0F, 0.0F, 0.0F);");
		
		// RenderEngine.class
		
		CtClass renderEngine = pool.get(RenderEngine);
		
 		CtClass stringParameter[] = {pool.get("java.lang.String")};
 		
		CtMethod getTexture = renderEngine.getDeclaredMethod(RenderEngine_getTexture, stringParameter);

		getTexture.instrument(
			new ExprEditor() {
				public void edit(MethodCall m) throws CannotCompileException {
					if (m.getClassName().equals(TexturePackBase) && m.getMethodName().equals(TexturePackBase_getStream) && m.getSignature().equals("(Ljava/lang/String;)Ljava/io/InputStream;")) {
						m.replace("{ $_ = $proceed($$); if ($_ == null) { return 0; } }");
					}
				}
			}
		);

		// RenderGlobal.class
		
		CtClass renderGlobal = pool.get(RenderGlobal);
 		
		CtMethod renderSky = renderGlobal.getDeclaredMethod(RenderGlobal_renderSky, floatParameter);

		renderSky.instrument(
			new ExprEditor() {
				public void edit(MethodCall m) throws CannotCompileException {
					if (m.getClassName().equals(World) && m.getMethodName().equals(World_getStarBrightness) && m.getSignature().equals("(F)F")) {
						m.replace("{ $_ = $proceed($$); Shaders.setCelestialPosition(); }");
					}
				}
			}
		);

		// RenderLiving.class
		
		CtClass renderLiving = pool.get(RenderLiving);
 		
		CtClass entityLiving = pool.get(EntityLiving);
		
 		CtClass doRenderLivingParameter[] = {entityLiving, CtClass.doubleType, CtClass.doubleType, CtClass.doubleType, CtClass.floatType, CtClass.floatType};

		CtMethod doRenderLiving = renderLiving.getDeclaredMethod(RenderLiving_doRenderLiving, doRenderLivingParameter);

		doRenderLiving.instrument(
			new ExprEditor() {
				public void edit(MethodCall m) throws CannotCompileException {
					if (m.getClassName().equals("org.lwjgl.opengl.GL11") && m.getMethodName().equals("glBlendFunc")) {
						m.replace("{ $_ = $proceed($$); Shaders.useProgram(Shaders.baseProgramNoT2D); }");
					}
				}
			}
		);

		doRenderLiving.instrument(
			new ExprEditor() {
				public void edit(MethodCall m) throws CannotCompileException {
					if (m.getClassName().equals("org.lwjgl.opengl.GL11") && m.getMethodName().equals("glDepthFunc")) {
						m.replace("{ $_ = $proceed($$); if ($1 == 515) { Shaders.useProgram(Shaders.baseProgram); } }");
					}
				}
			}
		);
		
		// Minecraft.class
		
		CtClass minecraft = pool.get(Minecraft);
		
		CtMethod startGame = minecraft.getDeclaredMethod(Minecraft_startGame, noParameter);
		
		startGame.instrument(
			new ExprEditor() {
				public void edit(MethodCall m) throws CannotCompileException {
					if (m.getClassName().equals("org.lwjgl.opengl.Display") && m.getMethodName().equals("create")) {
						m.replace("{ $_ = $proceed($$); Shaders.setUpBuffers(this); }");
					} else if (m.getClassName().equals("org.lwjgl.opengl.GL11") && m.getMethodName().equals("glViewport")) {
						m.replace("{ Shaders.viewport($$); }");
					}
				}
			}
		);
		
		CtMethod loadScreen = minecraft.getDeclaredMethod(Minecraft_loadScreen, noParameter);

		loadScreen.instrument(
			new ExprEditor() {
				public void edit(MethodCall m) throws CannotCompileException {
					if (m.getClassName().equals("org.lwjgl.opengl.GL11") && m.getMethodName().equals("glViewport")) {
						m.replace("{ Shaders.viewport($$); }");
					}
				}
			}
		);
		
		CtMethod run = minecraft.getDeclaredMethod(Minecraft_run, noParameter);
		
		run.instrument(
			new ExprEditor() {
				public void edit(MethodCall m) throws CannotCompileException {
					if (m.getClassName().equals("org.lwjgl.opengl.Display") && m.getMethodName().equals("update")) {
						m.replace("{ Shaders.updateDisplay(this); }");
					}
				}
			}
		);
		
		CtClass takeScreenshotParameter[] = {pool.get("java.io.File"), CtClass.intType, CtClass.intType, CtClass.intType, CtClass.intType};
		
		CtMethod takeScreenshot = minecraft.getDeclaredMethod(Minecraft_takeScreenshot, noParameter);
		
		takeScreenshot.instrument(
			new ExprEditor() {
				public void edit(MethodCall m) throws CannotCompileException {
					if (m.getClassName().equals("org.lwjgl.opengl.Display") && m.getMethodName().equals("update")) {
						m.replace("{ Shaders.updateDisplay(this); }");
					}
				}
			}
		);
		
		CtMethod toggleFullscreen = minecraft.getDeclaredMethod(Minecraft_toggleFullscreen, noParameter);
		
		toggleFullscreen.instrument(
			new ExprEditor() {
				public void edit(MethodCall m) throws CannotCompileException {
					if (m.getClassName().equals("org.lwjgl.opengl.Display") && m.getMethodName().equals("update")) {
						m.replace("{ Shaders.updateDisplay(this); }");
					}
				}
			}
		);
		
		CtClass int2Parameter[] = {CtClass.intType, CtClass.intType};
		
		CtMethod resize = minecraft.getDeclaredMethod(Minecraft_startGame, int2Parameter);
		
		resize.insertAfter("Shaders.setUpBuffers(this);");
		
		// GuiVideoSettings.class
		
		CtClass guiVideoSettings = pool.get(GuiVideoSettings);
		
		CtMethod initGui = guiVideoSettings.getDeclaredMethod(GuiVideoSettings_initGui, noParameter);
				
		initGui.insertAfter("Shaders.addVideoSettings(" + GuiScreen_controlList + ", " + GuiScreen_width + ", " + GuiScreen_height + ", " + GuiVideoSettings_options + ".length);");
		
		CtClass guiButtonParameter[] = {pool.get(GuiButton)};
		
		CtMethod actionPerformed = guiVideoSettings.getDeclaredMethod(GuiVideoSettings_actionPerformed, guiButtonParameter);
		
		actionPerformed.insertAfter("Shaders." + GuiVideoSettings_actionPerformed + "($1);");

		// WorldRenderer.class
		
		CtClass worldRenderer = pool.get(WorldRenderer);
		
		CtMethod updateRenderer = worldRenderer.getDeclaredMethod(WorldRenderer_updateRenderer, noParameter);

		updateRenderer.instrument(
			new ExprEditor() {
				public void edit(MethodCall m) throws CannotCompileException {
					if (m.getClassName().equals(RenderBlocks) && m.getMethodName().equals(RenderBlocks_renderBlockByRenderType) && m.getSignature().equals(RenderBlocks_renderBlockByRenderType_sig)) {
						m.replace("{ if (Shaders.entityAttrib >= 0) { " + Tessellator + "." + Tessellator_instance + ".setEntity($1." + Block_blockId + ", " + WorldRenderer_worldObj + "." + World_getBlockLightValue + "($2, $3, $4), " + Block + "." + Block_lightValue + "[$1." + Block_blockId + "]); } $_ = $proceed($$); }");
					}
				}
			}
		);
		
		updateRenderer.insertAfter("if (Shaders.entityAttrib >= 0) { " + Tessellator + "." + Tessellator_instance + ".setEntity(-1, 0, 0); }");
		
		// Finish up
		
		renderLiving.writeFile(dirPath);	
		renderGlobal.writeFile(dirPath);
		entityRenderer.writeFile(dirPath);
		tessellator.writeFile(dirPath);
		renderBlocks.writeFile(dirPath);
		renderEngine.writeFile(dirPath);
		guiVideoSettings.writeFile(dirPath);
		worldRenderer.writeFile(dirPath);
		minecraft.writeFile(dirPath);

		return true;
	}
	
	public boolean alreadyInstalled = false;
	
	// Obfuscated names. Hopefully this is all that will need to be changed for future releases.

	static final String EntityRenderer = "oy";
	static final String EntityRenderer_mc = "h";
	static final String EntityRenderer_renderEverything = "b";
	static final String EntityRenderer_renderWorld = "c";
	static final String EntityRenderer_renderPlayer = "b";
	static final String EntityRenderer_red = "e";
	static final String EntityRenderer_green = "this.f";
	static final String EntityRenderer_blue = "g";
	
	static final String Frustrum = "rn";
	
	static final String EntityLiving = "kw";

	static final String RenderGlobal = "m";	
	static final String RenderGlobal_renderClouds = "b";
	static final String RenderGlobal_renderTerrain = "a";
	static final String RenderGlobal_renderTerrain_sig = "(L"+EntityLiving+";ID)I";
	static final String RenderGlobal_renderSky = "a";

	static final String Minecraft_renderEngine = "o";
	
	static final String RenderEngine = "ip";
	static final String RenderEngine_getTexture = "a";
	
	static final String TexturePackBase = "h";
	static final String TexturePackBase_getStream = "a";

	static final String Tessellator = "na";
	static final String Tessellator_instance = "a";
	static final String Tessellator_draw = "a";
	static final String Tessellator_reset = "d";
	static final String Tessellator_setNormal = "b";
	static final String Tessellator_normal = "v";
	static final String Tessellator_addVertex = "a";
	static final String Tessellator_addedVertices = "p";
	static final String Tessellator_drawMode = "r";
	static final String Tessellator_convertQuadsToTriangles = "b";
	static final String Tessellator_hasNormals = "n";
	static final String Tessellator_rawBuffer = "g";
	static final String Tessellator_rawBufferIndex = "o";
	
	static final String Block = "to";
	static final String Block_lightValue = "s";
	static final String Block_blockId = "bl";

	static final String RenderBlocks = "cn";
	static final String RenderBlocks_renderBottomFace = "a";
	static final String RenderBlocks_renderTopFace = "b";
	static final String RenderBlocks_renderEastFace = "c";
	static final String RenderBlocks_renderWestFace = "d";
	static final String RenderBlocks_renderNorthFace = "e";
	static final String RenderBlocks_renderSouthFace = "f";
	static final String RenderBlocks_renderBlockByRenderType = "a";
	static final String RenderBlocks_renderBlockByRenderType_sig = "(L"+Block+";III)Z";

	static final String World = "et";
	static final String World_getStarBrightness = "e";
	static final String World_getBlockLightValue = "l";
	
	static final String RenderLiving = "gk";
	static final String RenderLiving_doRenderLiving = "a";

	static final String Minecraft = "net.minecraft.client.Minecraft";
	static final String Minecraft_startGame = "a";
	static final String Minecraft_loadScreen = "w";
	static final String Minecraft_run = "run";
	static final String Minecraft_takeScreenshot = "a";
	static final String Minecraft_toggleFullscreen = "i";
	static final String Minecraft_resize = "a";
	static final String Minecraft_gameSettings = "y";
	static final String Minecraft_displayGuiScreen = "a";

	static final String GuiVideoSettings = "mn";
	static final String GuiVideoSettings_initGui = "a";
	static final String GuiVideoSettings_actionPerformed = "a";
	static final String GuiVideoSettings_options = "l";

	static final String GuiButton = "jk";
	
	static final String GuiScreen_width = "c";
	static final String GuiScreen_height = "d";
	static final String GuiScreen_controlList = "e";

	static final String WorldRenderer = "dc";
	static final String WorldRenderer_updateRenderer = "a";
	static final String WorldRenderer_worldObj = "a";
	
	static final String GLAllocation = "ft";
	static final String GLAllocation_createDirectByteBuffer = "b";	
}