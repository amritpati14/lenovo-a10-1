#include <linux/delay.h>
#include <linux/i2c.h>
#include <linux/leds.h>
#include <linux/slab.h>
#include <linux/platform_device.h>
#include <linux/fs.h>
#include <linux/workqueue.h>
#include <linux/platform_data/leds-lm3642.h>
#include <mach/gpio.h>
#include <plat/rk_camera.h> 
#define DEB_LM3642
#ifdef DEB_LM3642
#define dprintk(fmt, arg...) do {			\	
	printk(fmt , ## arg); } while (0)
#else
#define dprintk(fmt, arg...) 
#endif

#define LM3642_NAME "leds-lm3642"
#define LM3642_DEBUG
//#define FLASH_GPIO_MODE

#define	REG_FILT_TIME			(0x0)
#define	REG_TORCH_TIME			(0x6)
#define	REG_FLASH			(0x8)
#define	REG_I_CTRL			(0x9)
#define	REG_ENABLE			(0xA)
#define	REG_FLAG			(0xB)


#define	TORCH_RAMP_UP_TIME_SHIFT	(3)
#define	TORCH_RAMP_DN_TIME_SHIFT	(0)
#define	FLASH_RAMP_TIME_SHIFT		(3)
#define	FLASH_TOUT_TIME_SHIFT		(0)
#define	TORCH_I_SHIFT			(4)
#define	FLASH_I_SHIFT			(0)
#define	TX_PIN_EN_SHIFT			(6)
#define	STROBE_PIN_EN_SHIFT		(5)
#define	TORCH_PIN_EN_SHIFT		(4)
#define	MODE_BITS_SHIFT			(0)

#define	TORCH_RAMP_UP_TIME_MASK		(0x7)
#define	TORCH_RAMP_DN_TIME_MASK		(0x7)
#define	FLASH_RAMP_TIME_MASK		(0x7)
#define	FLASH_TOUT_TIME_MASK		(0x7)
#define	TORCH_I_MASK			(0x7)
#define	FLASH_I_MASK			(0xF)
#define	TX_PIN_EN_MASK			(0x1)
#define	STROBE_PIN_EN_MASK		(0x1)
#define	TORCH_PIN_EN_MASK		(0x1)
#define	MODE_BITS_MASK			(0x73)
#define    EX_PIN_ENABLE_MASK		(0x70)
#define    CONFIG_SENSOR_I2C_SPEED    200000       /* Hz */

enum lm3642_mode {
	MODES_STASNDBY = 0,
	MODES_INDIC,
	MODES_TORCH,
	MODES_FLASH
};

struct lm3642_chip_data {
	struct device *dev;
	struct i2c_client *client;
	
	struct led_classdev cdev_flash;
	struct led_classdev cdev_torch;

	struct work_struct work_flash;
	struct work_struct work_torch;

	u8 br_flash;
	u8 br_torch;
	u8 torch_level;
	u8 flash_level;
	unsigned int strobe_gpio;
	unsigned int torch_gpio;
	unsigned int strobe_gpio_active;
	unsigned int torch_gpio_active;
	
	enum lm3642_torch_pin_enable torch_pin;
	enum lm3642_strobe_pin_enable strobe_pin;
	enum lm3642_tx_pin_enable tx_pin;

	struct lm3642_platform_data *pdata;	
	struct mutex lock;

	unsigned int last_flag;
};
static struct lm3642_chip_data *g_lm3642_chip = NULL;

static int lm3642_read(struct i2c_client *client, unsigned char reg, u8 *val)
{
#if 1
    int err,cnt;
    char reg_buf = reg;
    struct i2c_msg msg[2];
    

    msg[0].addr = client->addr;
    msg[0].flags = client->flags;
    msg[0].buf = &reg_buf;
    msg[0].len = sizeof(reg_buf);
    msg[0].scl_rate = CONFIG_SENSOR_I2C_SPEED;    
   // msg[0].read_type = 2;   
    
    msg[1].addr = client->addr;
    msg[1].flags = client->flags|I2C_M_RD;
    msg[1].buf = val;
    msg[1].len = 1;
    msg[1].scl_rate = CONFIG_SENSOR_I2C_SPEED;                      
   // msg[1].read_type = 2;                         

    cnt = 3;
    err = -EAGAIN;
    if (client == NULL)
    {
    	printk("client is null\n");return  -1;
    }
    //printk("client->addr = 0x%08x\n",client->addr);
    while ((cnt-- > 0) && (err < 0)) {                      
        err = i2c_transfer(client->adapter, msg, 2);
        if (err >= 0) {            
            return 0;
        } else {
        		printk("\n bitland:lm3642: %s read reg(0x%x val:0x%x) failed, try to read again! \n",reg, *val);
            udelay(10);
        }
    }

    return err;
#else
	struct i2c_adapter *adap=client->adapter;
	struct i2c_msg msgs[2];
	int ret;
	char reg_buf = reg;
	
	msgs[0].addr = client->addr;
	msgs[0].flags = client->flags;
	msgs[0].len = 1;
	msgs[0].buf = &reg_buf;
	msgs[0].scl_rate = scl_rate;
	msgs[0].udelay = client->udelay;

	msgs[1].addr = client->addr;
	msgs[1].flags = client->flags | I2C_M_RD;
	msgs[1].len = count;
	msgs[1].buf = (char *)buf;
	msgs[1].scl_rate = scl_rate;
	msgs[1].udelay = client->udelay;

	ret = i2c_transfer(adap, msgs, 2);

	return (ret == 2)? count : ret;
#endif
}

static int lm3642_write(struct i2c_client *client, unsigned char reg, u8 val)
{
    int err,cnt;
    unsigned char tx_buf[2];
    struct i2c_msg msg[1];
	
    printk("lm3642_write\n");
    tx_buf[0] = reg;
    tx_buf[1] = val;

    msg->addr = client->addr;
    msg->flags = client->flags;
    msg->buf = &tx_buf;
    msg->len = sizeof(tx_buf);
    msg->scl_rate = CONFIG_SENSOR_I2C_SPEED;        
    //msg->read_type = 0;              

    cnt = 3;
    err = -EAGAIN;

    while ((cnt-- > 0) && (err < 0)) {                    
        err = i2c_transfer(client->adapter, msg, 1);

        if (err >= 0) {
            return 0;
        } else {
            printk("\n bitland , lm3642: %s write reg(0x%x, val:0x%x) failed, try to write again!\n",reg, val);
            udelay(10);
        }
    }

    return err;
}

static int lm3642_rx_data(struct i2c_client *client, char *rxData, int length)
{
	int ret = 0;
	char reg = rxData[0];
	
	//ret = i2c_master_reg8_recv(client, reg, rxData, length, us5151_scl*1000);
	return (ret > 0)? 0 : ret;
}

static void dump_reg(struct i2c_client *client)
{
	unsigned char  reg_ena,flash_time;
	unsigned char reg_cur,torch_time, flag;
	reg_ena = flash_time=reg_cur=torch_time=torch_time=flag =0;
	
	lm3642_read(client, REG_FLAG, &flag);
	lm3642_read(client, REG_ENABLE, &reg_ena);
	lm3642_read(client, REG_FLASH, &flash_time);
	lm3642_read(client, REG_I_CTRL, &reg_cur);
	lm3642_read(client, REG_TORCH_TIME, &torch_time);
	printk("enable = 0x%02x, flash time=0x%02x, current=0x%02x, torch time=0x%02x, flag=0x%02x\n",
			reg_ena, flash_time, reg_cur, torch_time, flag);
}

static int __lm3642_update_bits(struct i2c_client *client,unsigned int reg,
			       unsigned int mask, unsigned int val
			       )
{
	int ret;
	unsigned int tmp, orig, rval;

	ret = lm3642_read(client, reg, &orig);
	if (ret != 0)
		return ret;

	tmp = orig & ~mask;
	tmp |= val & mask;

	if (tmp != orig) {
		ret = lm3642_write(client, reg, tmp);		
	} else {
		
	}

#ifdef LM3642_DEBUG	
	rval = 0;
	ret = lm3642_read(client, reg, &rval);
	if (ret != 0)
	{
		
		return ret;
	}
	printk("reg=0x%02x,rb:0x%02x,tmp=0x%02x\n",reg,rval, tmp);
	
#endif
	return ret;
}

static int lm3642_update_bits(struct i2c_client *client,unsigned int reg,
		       unsigned int mask, unsigned int val)
{
	int ret;
	ret = __lm3642_update_bits(client, reg, mask, val);
	return ret;
}

static int lm3642_chip_init(struct lm3642_chip_data *chip)
{
	int ret=0;
	struct lm3642_platform_data *pdata = chip->pdata;	
	ret = gpio_request(g_lm3642_chip->torch_gpio, NULL);
	if (ret != 0) 
	{
		printk("gpio_request failed\n");		
		return -1;
	}
#if 0	  /*set at rk_camera*/
	gpio_request(g_lm3642_chip->strobe_gpio, NULL);
	if (ret != 0) 
	{
		printk("gpio_request failed\n");		
		gpio_free(g_lm3642_chip->torch_gpio);
	}
	/* set enable register */
	gpio_direction_output(g_lm3642_chip->strobe_gpio, !g_lm3642_chip->strobe_gpio_active);	
	gpio_set_value(g_lm3642_chip->strobe_gpio, !g_lm3642_chip->strobe_gpio_active);
	udelay(100);	
#endif
		
		
	gpio_direction_output(g_lm3642_chip->torch_gpio, !g_lm3642_chip->torch_gpio_active);	
	gpio_set_value(g_lm3642_chip->torch_gpio, !g_lm3642_chip->torch_gpio_active);		
	printk("lm3642_chip_init read default value\n");
	dump_reg(chip->client);
	#if 0
	ret = lm3642_update_bits(chip->client, REG_ENABLE, EX_PIN_ENABLE_MASK,
				 pdata->tx_pin);
	if (ret < 0)
		dev_err(chip->dev, "Failed to update REG_ENABLE Register\n");
	#endif
	
	return ret;
}


static int lm3642_control(struct lm3642_chip_data *chip,
			  u8 brightness, enum lm3642_mode opmode)
{
	int ret = 0;
	unsigned char torch_time;
	if (!brightness)
		opmode = MODES_STASNDBY;		
	switch (opmode) {
	case MODES_TORCH:
		ret = lm3642_update_bits(chip->client, REG_I_CTRL,
					 TORCH_I_MASK << TORCH_I_SHIFT,
					 (brightness - 1) << TORCH_I_SHIFT);	
		torch_time = (7 << TORCH_RAMP_DN_TIME_SHIFT) |(7<<TORCH_RAMP_UP_TIME_SHIFT);
		ret = lm3642_update_bits(chip->client, REG_TORCH_TIME,
					 (FLASH_TOUT_TIME_MASK << TORCH_RAMP_DN_TIME_SHIFT )
					 |(FLASH_TOUT_TIME_MASK << TORCH_RAMP_UP_TIME_SHIFT ),
					torch_time );
		break;
	case MODES_FLASH:
		ret = lm3642_update_bits(chip->client, REG_I_CTRL,
					 FLASH_I_MASK << FLASH_I_SHIFT,
					 (brightness - 1) << FLASH_I_SHIFT);		
		break;
	default:
		return ret;
	}	

	ret = lm3642_update_bits(chip->client, REG_ENABLE,
				 MODE_BITS_MASK << MODE_BITS_SHIFT,
				 opmode << MODE_BITS_SHIFT);
	if (opmode == MODES_TORCH)
	{			
		gpio_set_value(g_lm3642_chip->torch_gpio, g_lm3642_chip->torch_gpio_active);
	}
	else if (opmode == MODES_FLASH)
	{		
		gpio_set_value(g_lm3642_chip->strobe_gpio, g_lm3642_chip->strobe_gpio_active);
	}
	else
	{
		gpio_set_value(g_lm3642_chip->torch_gpio, !g_lm3642_chip->torch_gpio_active);
	}
out:
	return ret;
}

/* torch pin config for lm3642*/
static ssize_t lm3642_torch_pin_store(struct device *dev,
				      struct device_attribute *devAttr,
				      const char *buf, size_t size)
{
	ssize_t ret;
	struct led_classdev *led_cdev = dev_get_drvdata(dev);
	struct lm3642_chip_data *chip =
	    container_of(led_cdev, struct lm3642_chip_data, cdev_torch);
	unsigned int state;

	ret = kstrtouint(buf, 10, &state);
	if (ret)
		goto out_strtoint;
	if (state != 0)
		state = 0x01 << TORCH_PIN_EN_SHIFT;

	chip->torch_pin = state;
	ret = lm3642_update_bits(chip->client, REG_ENABLE,
				 TORCH_PIN_EN_MASK << TORCH_PIN_EN_SHIFT,
				 state);
	if (ret < 0)
		goto out;

	return size;
out:
	dev_err(chip->dev, "%s:i2c access fail to register\n", __func__);
	return ret;
out_strtoint:
	dev_err(chip->dev, "%s: fail to change str to int\n", __func__);
	return ret;
}

static DEVICE_ATTR(torch_pin, S_IWUSR, NULL, lm3642_torch_pin_store);

static void lm3642_torch_work(struct work_struct *work)
{
	struct lm3642_chip_data *chip =
	    container_of(work, struct lm3642_chip_data, work_torch);

	mutex_lock(&chip->lock);
	lm3642_control(chip, chip->br_torch, MODES_TORCH);
	mutex_unlock(&chip->lock);
}

static void lm3642_torch_brightness_set(struct led_classdev *cdev,
					enum led_brightness brightness)
{
	struct lm3642_chip_data *chip =
	    container_of(cdev, struct lm3642_chip_data, cdev_torch);

	chip->br_torch = brightness;
	schedule_work(&chip->work_torch);
}

int lm3642_flash_torch(int cmd)
{	
	unsigned char mode;
	switch (cmd) 
	{
		case Flash_Off:  
		{
			dprintk("lm3642 flash off\n");
			gpio_set_value(g_lm3642_chip->torch_gpio, !g_lm3642_chip->torch_gpio_active); //tx/torch pin low
			udelay(100);
			break;
		}
		case Flash_On: 
		{		
			dprintk("lm3642 flash on\n");
			mode = 0x3 |(STROBE_PIN_EN_MASK << STROBE_PIN_EN_SHIFT);
			lm3642_update_bits(g_lm3642_chip->client, REG_ENABLE,
				 MODE_BITS_MASK << MODE_BITS_SHIFT,
				 mode << MODE_BITS_SHIFT);
			gpio_direction_output(g_lm3642_chip->strobe_gpio, g_lm3642_chip->strobe_gpio_active);	
			gpio_set_value(g_lm3642_chip->strobe_gpio, g_lm3642_chip->strobe_gpio_active);
			break;
		}
		case Flash_Torch:
		{
			dprintk("lm3642 flash torch on\n");
			mode = 0x2 |(TORCH_PIN_EN_MASK << TORCH_PIN_EN_SHIFT);
			lm3642_update_bits(g_lm3642_chip->client, REG_ENABLE,
				 MODE_BITS_MASK << MODE_BITS_SHIFT,
				 mode << MODE_BITS_SHIFT);
			gpio_direction_output(g_lm3642_chip->torch_gpio, g_lm3642_chip->torch_gpio_active);	
			gpio_set_value(g_lm3642_chip->torch_gpio, g_lm3642_chip->torch_gpio_active);
			break;
		}
		default: {
			printk("%s..Flash command:%d  is invalidate \n",cmd,__FUNCTION__);			
			break;
		}
	}
		
	return 0;
}

int leds_flash_torch(int cmd)
{
	return lm3642_flash_torch(cmd);
}

EXPORT_SYMBOL_GPL(leds_flash_torch);

static ssize_t lm3642_debug(struct device *dev,
				       struct device_attribute *devAttr,
				       const char *buf, size_t size)
{
	ssize_t ret;
	struct led_classdev *led_cdev = dev_get_drvdata(dev);
	struct lm3642_chip_data *chip =
	    container_of(led_cdev, struct lm3642_chip_data, cdev_flash);
	unsigned int state;
	printk("strobe_pin_store cmd=%s\n", buf);
	ret = kstrtouint(buf+1, 10, &state);
	unsigned char mode;
	if (ret)
		return ret;
	
	printk("state:0x%x\n", state);	
	if (buf[0] == 's')
	{		
		if (state ==1)
		{
			lm3642_flash_torch(Flash_On);
		}
		else if (state ==2)
		{
			lm3642_flash_torch(Flash_Torch);
		}	
		else if (state ==3)
		{
			lm3642_flash_torch(Flash_Off);
		}
	}	
	return size;
out:
	dev_err(chip->dev, "%s:i2c access fail to register\n", __func__);
	return ret;
}

static DEVICE_ATTR(strobe_pin, S_IWUSR, NULL, lm3642_debug);

static void lm3642_flash_work(struct work_struct *work)
{
	struct lm3642_chip_data *chip =
	    container_of(work, struct lm3642_chip_data, work_flash);

	mutex_lock(&chip->lock);
	lm3642_control(chip, chip->br_flash, MODES_FLASH);
	mutex_unlock(&chip->lock);
}

static void lm3642_flash_brightness_set(struct led_classdev *cdev,
					 enum led_brightness brightness)
{
	struct lm3642_chip_data *chip =
	    container_of(cdev, struct lm3642_chip_data, cdev_flash);

	chip->br_flash = brightness;
	schedule_work(&chip->work_flash);
}

static int lm3642_probe(struct i2c_client *client,
				  const struct i2c_device_id *id)
{
	struct lm3642_platform_data *pdata = client->dev.platform_data;
	struct lm3642_chip_data *chip;

	int err;
	printk("lm3642_probe\n");
	if (!i2c_check_functionality(client->adapter, I2C_FUNC_I2C)) {
		dev_err(&client->dev, "i2c functionality check fail.\n");
		return -EOPNOTSUPP;
	}

	if (pdata == NULL) {
		dev_err(&client->dev, "needs Platform Data.\n");
		return -ENODATA;
	}

	chip = kzalloc(sizeof(struct lm3642_chip_data), GFP_KERNEL);
	if (!chip)
		return -ENOMEM;

	chip->client = client;
	chip->dev = &client->dev;
	chip->pdata = pdata;

	chip->tx_pin = pdata->tx_pin;
	chip->torch_pin = pdata->torch_pin;
	chip->strobe_pin = pdata->strobe_pin;	
	chip->strobe_gpio = pdata->gpio_strobe;
	chip->torch_gpio = pdata->gpio_torch;
	chip->strobe_gpio_active = pdata->strobe_active;
	chip->torch_gpio_active = pdata->torch_active;
	
	g_lm3642_chip = chip;
	printk("bitland:tx=%d, tourch=%d, strobe=%d\n", chip->tx_pin, chip->torch_pin, chip->strobe_pin);
	mutex_init(&chip->lock);
	i2c_set_clientdata(client, chip);

	err = lm3642_chip_init(chip);
	if (err < 0)
	{
		printk("failed to init lm3642\n");
		goto err_out;
	}

	INIT_WORK(&chip->work_flash, lm3642_flash_work);
	chip->cdev_flash.name = "flash";
	chip->cdev_flash.max_brightness = 16;
	chip->cdev_flash.brightness_set = lm3642_flash_brightness_set;
	err = led_classdev_register((struct device *)
				    &client->dev, &chip->cdev_flash);
	if (err < 0) {
		dev_err(chip->dev, "failed to register flash\n");
		goto err_out;
	}
	err = device_create_file(chip->cdev_flash.dev, &dev_attr_strobe_pin);
	if (err < 0) {
		dev_err(chip->dev, "failed to create strobe-pin file\n");
		goto err_create_flash_pin_file;
	}

	INIT_WORK(&chip->work_torch, lm3642_torch_work);
	chip->cdev_torch.name = "torch";
	chip->cdev_torch.max_brightness = 8;
	chip->cdev_torch.brightness_set = lm3642_torch_brightness_set;
	err = led_classdev_register((struct device *)
				    &client->dev, &chip->cdev_torch);
	if (err < 0) {
		dev_err(chip->dev, "failed to register torch\n");
		goto err_create_torch_file;
	}
	err = device_create_file(chip->cdev_torch.dev, &dev_attr_torch_pin);
	if (err < 0) {
		dev_err(chip->dev, "failed to create torch-pin file\n");
		goto err_create_torch_pin_file;
	}
	
	dev_info(&client->dev, "LM3642 is initialized\n");
	return 0;

	device_remove_file(chip->cdev_torch.dev, &dev_attr_torch_pin);
err_create_torch_pin_file:
	led_classdev_unregister(&chip->cdev_torch);
err_create_torch_file:
	device_remove_file(chip->cdev_flash.dev, &dev_attr_strobe_pin);
err_create_flash_pin_file:
	led_classdev_unregister(&chip->cdev_flash);
err_out:
         if (chip !=NULL)
         {
         	kfree(chip);
         }
	return err;
}

static int lm3642_remove(struct i2c_client *client)
{
	struct lm3642_chip_data *chip = i2c_get_clientdata(client);
	
	device_remove_file(chip->cdev_torch.dev, &dev_attr_torch_pin);
	led_classdev_unregister(&chip->cdev_torch);
	flush_work(&chip->work_torch);
	device_remove_file(chip->cdev_flash.dev, &dev_attr_strobe_pin);
	led_classdev_unregister(&chip->cdev_flash);
	flush_work(&chip->work_flash);
	lm3642_write(client, REG_ENABLE, 0);
	kfree(chip);
	return 0;
}

static const struct i2c_device_id lm3642_id[] = {
	{LM3642_NAME, 0},
	{}
};

MODULE_DEVICE_TABLE(i2c, lm3642_id);

static struct i2c_driver lm3642_i2c_driver = {
	.driver = {
		   .name = LM3642_NAME,
		   .owner = THIS_MODULE,
		   .pm = NULL,
		   },
	.probe = lm3642_probe,
	.remove = lm3642_remove,
	.id_table = lm3642_id,
};

static int __init lm3642_init(void)
{
	return i2c_add_driver(&lm3642_i2c_driver);
}

static void __exit lm3642_exit(void)
{
	i2c_del_driver(&lm3642_i2c_driver);
}

module_init(lm3642_init);
module_exit(lm3642_exit);

