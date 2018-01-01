#include "CanUse.as";

bool editor_cursor = false;

const string editor_place = "editor place";
const string editor_destroy = "editor destroy";
const string editor_copy = "editor copy";

const string cursorTexture = "../Mods/PrimitiveEditor/EditorCursor.png";
 
void onInit( CRules@ this )
{
    this.addCommandID(editor_place);
    this.addCommandID(editor_destroy);
	this.addCommandID(editor_copy);
}

void onTick(CRules@ this)
{
	if(getNet().isClient())
	{
		CPlayer@ p = getLocalPlayer();
		CMap@ map = getMap();
		if (p !is null)
		{
			bool op = CanUse(p.getUsername());
			if(op)
			{
				if (getControls().isKeyJustPressed(KEY_LCONTROL))
				{
					editor_cursor = !editor_cursor;
				}

				if (getControls().isKeyJustPressed(KEY_KEY_Z))
				{
					CBitStream params;
					params.write_u16(p.getNetworkID());
					this.SendCommand(this.getCommandID(editor_destroy), params);
				}
				if (getControls().isKeyPressed(KEY_LSHIFT))
				{
					if (getControls().isKeyJustPressed(KEY_KEY_X))
					{
						CBitStream params;
						params.write_u16(p.getNetworkID());
						this.SendCommand(this.getCommandID(editor_place), params);
					}
					if (getControls().isKeyJustPressed(KEY_KEY_Z))
					{
						CBitStream params;
						params.write_u16(p.getNetworkID());
						this.SendCommand(this.getCommandID(editor_destroy), params);
					}
				}
				else
				{
					if (getControls().isKeyPressed(KEY_KEY_X))
					{
						CBitStream params;
						params.write_u16(p.getNetworkID());
						this.SendCommand(this.getCommandID(editor_place), params);
					}
					if (getControls().isKeyPressed(KEY_KEY_Z))
					{
						CBitStream params;
						params.write_u16(p.getNetworkID());
						this.SendCommand(this.getCommandID(editor_destroy), params);
					}
				}
				if (getControls().isKeyJustPressed(KEY_KEY_B))
				{
					CBlob@ blob = p.getBlob();
					if (blob !is null)
					{
						Vec2f pos = blob.getAimPos();
						blob.set_TileType("buildtile", map.getTile(pos).type);
					}
					CBitStream params;
					params.write_u16(p.getNetworkID());
					this.SendCommand(this.getCommandID(editor_copy), params);
				}
			}
		}
	}
}

void onRender(CRules@ this)
{
	if(editor_cursor)
	{
		CPlayer@ p = getLocalPlayer();

		if (p is null || !p.isMyPlayer()) { return; }
		if (p.getBlob() !is null)
		{
			Vec2f position = Vec2f(int(p.getBlob().getAimPos().x/8), int(p.getBlob().getAimPos().y/8));
			position = getDriver().getScreenPosFromWorldPos(position*8 - Vec2f(1, 1));
			GUI::DrawIcon(cursorTexture, position, getCamera().targetDistance * getDriver().getResolutionScaleFactor());
		}
	}
}

void onCommand( CRules@ this, u8 cmd, CBitStream@ params )
{
    if (!getNet().isServer())
		return;

    if (cmd == this.getCommandID(editor_place))
	{
	    CPlayer@ p = ResolvePlayer(params);
		CMap@ map = getMap();
		CBlob@ blob = p.getBlob();
		if (blob !is null)
		{
			Vec2f pos = blob.getAimPos();
			CBlob@ behindBlob = getMap().getBlobAtPosition(pos);
			if (behindBlob !is null)
			{
				behindBlob.server_Die();
			}
			else
			{
				map.server_SetTile(pos, CMap::tile_empty);
			}
		}
	}
	else if (cmd == this.getCommandID(editor_destroy))
	{
	    CPlayer@ p = ResolvePlayer(params);
		CMap@ map = getMap();
		CBlob@ blob = p.getBlob();
		if (blob !is null)
		{
			Vec2f pos = blob.getAimPos();
			if (blob.get_TileType("buildtile") != 0)
				map.server_SetTile(pos, blob.get_TileType("buildtile"));
			else if (blob.getCarriedBlob() !is null)
			{
				if (canPlaceBlobAtPos(getBottomOfCursor(pos)))
				{
					CBlob@ newblob = server_CreateBlob(blob.getCarriedBlob().getName(), blob.getCarriedBlob().getTeamNum(), getBottomOfCursor(pos));
					if (newblob.isSnapToGrid())
					{
						CShape@ shape = newblob.getShape();
						shape.SetStatic(true);
					}
				}
			}
		}
	}
	else if (cmd == this.getCommandID(editor_copy))
	{
	    CPlayer@ p = ResolvePlayer(params);
		CMap@ map = getMap();
		CBlob@ blob = p.getBlob();
		if (blob !is null)
		{
			Vec2f pos = blob.getAimPos();
			blob.set_TileType("buildtile", map.getTile(pos).type);
		}
	}
}

bool canPlaceBlobAtPos( Vec2f pos )
{
	CBlob@ _tempBlob; CShape@ _tempShape;
	
	  @_tempBlob = getMap().getBlobAtPosition( pos );
	if(_tempBlob !is null && _tempBlob.isCollidable())
	{
		  @_tempShape = _tempBlob.getShape();
		if(_tempShape.isStatic())
		    return false;
	}
	return true;
}

CPlayer@ ResolvePlayer( CBitStream@ data )
{
    u16 playerNetID;
	if(!data.saferead_u16(playerNetID)) return null;
	
	return getPlayerByNetworkId(playerNetID);
}

Vec2f getBottomOfCursor(Vec2f cursorPos)
{
	cursorPos = getMap().getTileSpacePosition(cursorPos);
	cursorPos = getMap().getTileWorldPosition(cursorPos);
	f32 w = getMap().tilesize / 2.0f;
	f32 h = getMap().tilesize / 2.0f;
	int offsetY = Maths::Max(1, Maths::Round(8 / getMap().tilesize)) - 1;
	h -= offsetY * getMap().tilesize / 2.0f;
	return Vec2f(cursorPos.x + w, cursorPos.y + h);
}