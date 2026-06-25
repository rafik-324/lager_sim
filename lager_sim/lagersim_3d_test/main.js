import * as THREE from 'three';
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js';
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js';

const scene = new THREE.Scene();
scene.background = new THREE.Color(0xf0f0f0);

const camera = new THREE.PerspectiveCamera(45, window.innerWidth / window.innerHeight, 0.1, 1000);
camera.position.set(8, 6, 8);

const renderer = new THREE.WebGLRenderer({ antialias: true });
renderer.setSize(window.innerWidth, window.innerHeight);
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.1;
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
document.body.appendChild(renderer.domElement);

const controls = new OrbitControls(camera, renderer.domElement);
controls.target.set(0, 1, 0);

// Lights
scene.add(new THREE.AmbientLight(0xffffff, 0.6));
const keyLight = new THREE.DirectionalLight(0xffffff, 2.0);
keyLight.position.set(8, 12, 6);
keyLight.castShadow = false;
keyLight.shadow.mapSize.set(2048, 2048);
keyLight.shadow.bias = -0.0005;
scene.add(keyLight);
const fillLight = new THREE.DirectionalLight(0xffffff, 0.8);
fillLight.position.set(-6, 5, -4);
scene.add(fillLight);

// Boden für Schatten
const ground = new THREE.Mesh(
    new THREE.PlaneGeometry(50, 50),
    new THREE.ShadowMaterial({ opacity: 0.1 })
);
ground.rotation.x = -Math.PI / 2;
ground.receiveShadow = true;
scene.add(ground);

// Materialien pro Objekt-Typ, passend zum Referenzbild
const materials = {
    fuss: new THREE.MeshStandardMaterial({ color: 0xc8c8c8, roughness: 0.35, metalness: 0.7 }),
    strebe: new THREE.MeshStandardMaterial({ color: 0x4a5560, roughness: 0.4, metalness: 0.6 }),
    barrier: new THREE.MeshStandardMaterial({ color: 0xf5c518, roughness: 0.5, metalness: 0.1 }),
    ebene: new THREE.MeshStandardMaterial({ color: 0xe8e8e8, roughness: 0.5, metalness: 0.1 }),
    lager_einheit: new THREE.MeshStandardMaterial({ color: 0xf5f0a3, roughness: 0.8, metalness: 0 })
};

// Wird beim Laden des Models gesetzt, damit changeStorageUnit darauf zugreifen kann
let loadedModel = null;

// Model laden
new GLTFLoader().load('/models/lager_model.glb', (gltf) => {
    gltf.scene.traverse((obj) => {
        if (obj.isMesh) {
            obj.castShadow = true;
            obj.receiveShadow = true;

            const name = obj.name.toLowerCase();

            if (name.includes('fuss')) {
                obj.material = materials.fuss;
            } else if (name.includes('strebe')) {
                obj.material = materials.strebe;
            } else if (name.includes('barrier')) {
                obj.material = materials.barrier;
            } else if (name.includes('ebene')) {
                obj.material = materials.ebene;
                obj.material.side = THREE.DoubleSide;
            } else if (name.includes('lager_einheit')) {
                obj.material = materials.lager_einheit;
            }
        }
    });
    scene.add(gltf.scene);
    loadedModel = gltf.scene;
});

// Färbt eine Lager-Einheit (per Namen, z.B. "aA1") zwischen der Basisfarbe
// (0xc9a876, bei 0 belegten Plätzen) und Rot (0xd42a2a, bei 100 belegten
// Plätzen) ein. occupiedSlots = Anzahl belegter Plätze (0-100), da jede
// Einheit 100 Plätze hat.
function changeStorageUnit(name, occupiedSlots) {
    if (!loadedModel) {
        console.warn('Model noch nicht geladen');
        return;
    }

    let obj = null;
    loadedModel.traverse((child) => {
        if (child.isMesh && child.name.toLowerCase().includes(name.toLowerCase())) {
            obj = child;
        }
    });

    if (!obj) {
        console.warn(`Objekt "${name}" nicht gefunden`);
        return;
    }

    if (!obj.userData.materialCloned) {
        obj.material = obj.material.clone();
        obj.userData.materialCloned = true;
    }

    const baseColor = new THREE.Color(0xf5f0a3);
    const targetColor = new THREE.Color(0xd42a2a);

    const t = Math.min(Math.max(occupiedSlots, 0), 100) / 100;

    obj.material.color.copy(baseColor).lerp(targetColor, t);
}

window.changeStorageUnit = changeStorageUnit;

window.changeStorageUnit = changeStorageUnit;

window.addEventListener('resize', () => {
    camera.aspect = window.innerWidth / window.innerHeight;
    camera.updateProjectionMatrix();
    renderer.setSize(window.innerWidth, window.innerHeight);
});

function animate() {
    requestAnimationFrame(animate);
    controls.update();
    renderer.render(scene, camera);
}
animate();