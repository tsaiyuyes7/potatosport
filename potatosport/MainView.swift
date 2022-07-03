//
//  MainView.swift
//  potatosport
//
//  Created by 蔡瑀 on 2022/6/19.
//

import SceneKit
import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseDatabase
import FirebaseDatabaseSwift

struct invitedToFriendRoom {
    var leaderId:String
    var inviteRoomId:String
    var leaderName:String
}

struct MainView: View {
    //  Auth資訊
    @State private var personalPage = false
    
    @EnvironmentObject var authViewModel:AppAuthViewModel
    //  配對房間資訊
    @EnvironmentObject var roomConnectViewModel:roomsConnetModel
    //  朋友房間，朋友資訊
    @EnvironmentObject var friendConnectViewModel:friendCoonectViewModel
    // sheet 資料
    @EnvironmentObject var globalSheet: GlobalSheet
    
    @EnvironmentObject var playerControl: musicControl
    
//    @Binding var isPlaying:Bool
    
    // 控制好友彈窗
    @State private var showAddFriendView = false
    // 控制模式彈窗
    @State private var showSelectmodeView = false
    
    @State private var invitedInfo = invitedToFriendRoom(leaderId: "", inviteRoomId: "", leaderName: "")
    
    @State private var initedAlert = false
    
    
    
    func initObserve(){
        //--------  好友邀請監聽  ----------//
        var ref = Database.database().reference()
        ref.child("newFriend").child("\(authViewModel.userId)").observe(.value) { snapshot in
            if(snapshot.exists()){
                print("收到交友邀請")
                let snap = snapshot as! DataSnapshot
                let dict = snap.value as! [String:Any]
                let laucherId = dict["laucherId"] as! String
                let laucherName = dict["laucherName"] as! String
                let fr = Friend(name: laucherName, id: laucherId, isOnline: true)
                self.friendConnectViewModel.beInvited.append(fr)
            
            }
        }
        //-------- 有沒有人向自己發邀請加入好友房間  -----------//
        ref.child("inviteRoom").child("\(authViewModel.userId)").observe(.value) { snapshot in
            if(snapshot.exists()){
                print("加入好友的房間")
                if(self.friendConnectViewModel.friendRoomId == ""){
                    let snap = snapshot as! DataSnapshot
                    let dict = snap.value as! [String: Any]
                    let inviteRoomId = dict["inviteRoomId"] as! String
                    let leaderId = dict["leaderId"] as! String
                    let leaderName = dict["leaderName"] as! String
                    self.invitedInfo = invitedToFriendRoom(leaderId: leaderId, inviteRoomId: inviteRoomId, leaderName: leaderName)
                    self.initedAlert = true
                    
                }
                
            }
        }
    }
    
    // 監聽好友房間 (有無配對)
    func observeFriendRoom(){
        var ref = Database.database().reference()
        ref.child("friendRooms").child(friendConnectViewModel.friendRoomId).observe(.value) { snapshot in
            if snapshot.exists(){
                let snap = snapshot as! DataSnapshot
                let dict = snap.value as! [String:Any]
                if dict["leaderId"] == nil {
                    // 房主離開房間消失
                    friendConnectViewModel.exitFriendRoom(getOut:true)
                }else {
//                    let users = dict["users"] as! [String:Any]
                    if dict["users"] != nil {
                        let users = dict["users"] as! [String:Any]
                        for u in users {
                            let info = u.value as! [String:Any]
                            let id = info["id"] as! String
                            let name = info["userName"] as! String
                            let docs = UserPlayer(id: id, userName: name, point: 0, time: 0, ready: false)
                            friendConnectViewModel.selfPlyaers[id] = docs
                        }
                    }
                    // 房長告訴大家有房間了 開始監聽
                    let hasRoom = dict["hasRoom"] as! Bool
                    if hasRoom {
                        self.roomConnectViewModel.hasRoom = true
                        self.roomConnectViewModel.roomId = dict["roomId"] as! String
                        self.roomConnectViewModel.observerRoomFill()
                    }
                }
            }
        }
    }
    
    
    var body: some View {
        ZStack(alignment:.center) {
            Image("main_bg")
                //.frame(width:UIScreen.main.bounds.width,height:UIScreen.main.bounds.height)
                //.frame(width: 896, height: 414)
                .resizable()
                .scaledToFill()
                .edgesIgnoringSafeArea(.all)
            ZStack(alignment:.bottom) {
                if(self.friendConnectViewModel.selfPlyaers.count > 1) {
                    ZStack(alignment: .center){
                        ForEach(Array(self.friendConnectViewModel.selfPlyaers.keys.enumerated()),id:\.element) { _, key in
                            if(key != self.authViewModel.userId){
                                Image("main_player")
                                    .resizable(capInsets: EdgeInsets(top: -50, leading: 0, bottom: 50, trailing: 0))
                                .offset(x: -150, y: 10)
                                Text(friendConnectViewModel.selfPlyaers[key]?.userName ?? "")
                                    .foregroundColor(Color("dark"))
                                    .offset(x: -120, y: -80)
                            }
                        }
                    }
                }

               
                Image("main_player")
                    .resizable()
                    .scaledToFill()
                    .edgesIgnoringSafeArea(.all)
                    .offset(x: 0, y: 20)
            }
  
            MainUIView(personalPage:self.$personalPage, showAddFriendView: self.$showAddFriendView, showSelectmodeView:self.$showSelectmodeView)

            if self.showAddFriendView{
                AddFriendView(showAddFriendView: self.$showAddFriendView)
            }
            if self.showSelectmodeView{
                SelectmodeView(showSelectmodeView:self.$showSelectmodeView)
            }
           // LoadingView()
            if self.roomConnectViewModel.hasRoom && self.roomConnectViewModel.fill != true {
                    LoadingView()
            }
            if self.personalPage {
                PersonalView(showBackBtn: $personalPage)
            }
            
        }
        .frame(width:UIScreen.main.bounds.width,height:UIScreen.main.bounds.height)
        .onAppear{
            self.playerControl.mainBgm()
            self.roomConnectViewModel.initSetSelfPlayer(myId: authViewModel.userId, userName: authViewModel.userName)
            self.friendConnectViewModel.initSetFriend(myId: authViewModel.userId, myName: authViewModel.userName)
            self.initObserve()
        }
        .alert(isPresented: $initedAlert){
            Alert(
                title: Text("\(self.invitedInfo.leaderName)邀請你一起運動"),primaryButton: .default(Text("接受"),action: {
                    var ref = Database.database().reference()
                    
                    // API:接受好友房間邀請
                    self.roomConnectViewModel.frRoomId = self.friendConnectViewModel.friendRoomId
                    
                    self.friendConnectViewModel.acceptInviteGame(inviteRoomId: invitedInfo.inviteRoomId, myId: self.authViewModel.userId, myName: self.authViewModel.userName, leaderId: invitedInfo.leaderId, leaderName: invitedInfo.leaderName)
                    ref.child("inviteRoom").child("\(authViewModel.userId)").removeValue()
                }),secondaryButton: .default(Text("拒絕"),action: {
                    var ref = Database.database().reference()
                    print("拒絕邀請")
                    ref.child("inviteRoom").child("\(authViewModel.userId)").removeValue()
                })
            )
        }
        
    }
}
struct MainUIView: View {
    @Binding var personalPage: Bool
    @Binding var showAddFriendView:Bool
    @Binding var showSelectmodeView:Bool
//    @Binding var isPlaying:Bool
    
    @State private var mode:String = "mode2"
    
    //  Auth資訊
    @EnvironmentObject var authViewModel:AppAuthViewModel
    //  配對房間資訊
    @EnvironmentObject var roomConnectViewModel:roomsConnetModel
    //  朋友房間，朋友資訊
    @EnvironmentObject var friendConnectViewModel:friendCoonectViewModel
    
    @EnvironmentObject var playerControl:musicControl
    
    var body: some View {
        HStack(alignment:.top, spacing:50){
            VStack{
                HStack{}.frame(height:3)
                Button(action: {
                    self.personalPage = true
                }, label: {
                    ZStack(alignment: .center){
                        Image("main_userButton")
                        Text(authViewModel.userName).foregroundColor(Color("dark")).tracking(2).fontWeight(.regular).offset(x: 0, y: -3)
                    }
                })
                
                Spacer()
                HStack{
                    //HStack{}.frame(width:24)
                    Button(action: {
                       // print("click addfriend button")
                        self.showAddFriendView = true
                    }, label: {
                        
                        AddFriendBtnView()
                    })
                    //Spacer()
                }
               
                Spacer()
            }
            Spacer()
            VStack{
                HStack{}.frame(height:3)
                Button(action: {
                   // print("open selectmode button")
                }, label: {
                    ZStack(alignment: .center){
                        Image("main_changemode")
                        switch(self.roomConnectViewModel.mode){
                        case "mode1":
                            Text("吃雞模式").foregroundColor(Color("dark")).tracking(2).fontWeight(.black)
                        case "mode2":
                            Text("對戰模式").foregroundColor(Color("dark")).tracking(2).fontWeight(.black)
                        default:
                            Text("吃雞模式").foregroundColor(Color("dark")).tracking(2).fontWeight(.black)
                        }
                    }
                })
                Spacer()
            }
            Spacer()
            VStack(alignment:.trailing){
                Spacer()
                VStack(alignment:.trailing , spacing:30 ){
                    Button(action: {
                        self.playerControl.btnClickPlay()
                        self.showSelectmodeView = true
                    }, label: {
                        HStack{
                            ButtonView(button: Btn(name: "選擇模式", width: 112, height: 38.4,fontsize:14))
                            HStack{}.frame(width:6)
                        }
                        
                    })
                    Button(action: {
                        self.playerControl.btnClickPlay()
                    }, label: {
                        HStack{
                            ButtonView(button: Btn(name: "建立房間", width: 112, height: 38.4,fontsize:14))
                            HStack{}.frame(width:6)
                        }
                        
                    })
                    Button(action: {
                        if self.roomConnectViewModel.mode == "mode2" {
                            self.roomConnectViewModel.isPlaying = true
                        } else{
                            if friendConnectViewModel.isLeader && !roomConnectViewModel.hasRoom {
                                self.roomConnectViewModel.selfPlyaers = self.friendConnectViewModel.selfPlyaers
                                self.roomConnectViewModel.searchRoom()
                            }
                            else if friendConnectViewModel.isLeader && roomConnectViewModel.hasRoom{
                                self.roomConnectViewModel.outRoom()
                            }
                            else if !friendConnectViewModel.isLeader && !roomConnectViewModel.hasRoom{
                                self.friendConnectViewModel.exitFriendRoom(getOut: false)
                            }
                        }
                       
                    }, label: {
                        HStack{
                            if friendConnectViewModel.isLeader && !roomConnectViewModel.hasRoom {
                                ButtonView(button: Btn(name: "開始遊戲", width: 174, height: 50.4,fontsize: 20))
                            }
                            else if friendConnectViewModel.isLeader && roomConnectViewModel.hasRoom{
                                ButtonView(button: Btn(name: "取消配對", width: 174, height: 50.4,fontsize: 20))
                            }
                            else if !friendConnectViewModel.isLeader && roomConnectViewModel.hasRoom{
                                ButtonView(button: Btn(name: "配對中", width: 174, height: 50.4,fontsize: 20))
                            }
                            else if !friendConnectViewModel.isLeader && !roomConnectViewModel.hasRoom{
                                ButtonView(button: Btn(name: "退出房間", width: 174, height: 50.4,fontsize: 20))
                            }
                            HStack{}.frame(width:6)
                        }
                    })
                    HStack{}.frame(height:6)
                }
            }
        }
        .frame(width:UIScreen.main.bounds.width,height:UIScreen.main.bounds.height)
        //.frame(width: 860, height: 402)
        
    }
}



struct ModelView: View{
    
    var body: some View {
        SceneView(scene: {
            let scene = SCNScene(named: "toy_robot_vintage.usdz")!
            scene.background.contents = UIColor.clear/// here!
            return scene
        }(),
                  options: [.autoenablesDefaultLighting,.allowsCameraControl]
        )
        .frame(width:UIScreen.main.bounds.width,height:UIScreen.main.bounds.height / 2)
        
    }
}
//.frame(maxWidth: .infinity, maxHeight: .infinity)


struct MainView_Previews: PreviewProvider {
    static let authViewModel = AppAuthViewModel()
    //  配對房間資訊
    static let roomConnectViewModel = roomsConnetModel()
    //  朋友房間，朋友資訊
    static let friendConnectViewModel = friendCoonectViewModel()
    // sheet 資料
    static let globalSheet = GlobalSheet()
    @State static var show = true
    static var previews: some View {
        Group {
            MainView()
                .environmentObject(authViewModel)
                .environmentObject(roomConnectViewModel)
                .environmentObject(friendConnectViewModel)
                .environmentObject(globalSheet)
                .previewInterfaceOrientation(.landscapeRight)
        }
    }
}
