import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  
  // Enable CORS so your Flutter Web/Mobile can talk to it
  app.enableCors(); 
  
  // Listen on 0.0.0.0 to accept external connections in Docker/Railway
  await app.listen(process.env.PORT || 3000, '0.0.0.0');
  
  console.log(`Application is running on: ${await app.getUrl()}`);
}
bootstrap();